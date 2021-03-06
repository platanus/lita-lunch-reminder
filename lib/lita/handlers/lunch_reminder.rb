# coding: utf-8

require 'slack-ruby-client'

module Lita
  module Handlers
    class LunchReminder < Handler
      MAX_LUNCHERS = ENV.fetch('MAX_LUNCHERS').to_i
      MIN_LUNCHERS = MAX_LUNCHERS - 4
      EMISSION_INTERVAL_DAYS = ENV.fetch('EMISSION_INTERVAL_DAYS', 30)
      COOKING_CHANNEL = ENV.fetch('COOKING_CHANNEL')
      KARMA_AUDIT_CHANNEL = ENV.fetch('KARMA_AUDIT_CHANNEL')

      on :loaded, :load_on_start
      on :lunch_answer, :lunch_answer_cb

      def initialize(robot)
        super
        @karmanager = Lita::Services::Karmanager.new(redis)
        @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
        @emitter = Lita::Services::KarmaEmitter.new(redis, @karmanager)
        @market = Lita::Services::MarketManager.new(redis, @assigner, @karmanager)
        @slack_client = Slack::Web::Client.new
      end

      def self.help_msg(route)
        { "lunch-reminder: #{t("help.#{route}.usage")}" => t("help.#{route}.description") }
      end

      def load_on_start(_payload)
        create_schedule
      end

      route(/askme/i, command: true) do |response|
        ask_luncher(response.user.mention_name)
      end

      route(/gracias/i, command: true, help: help_msg(:thanks)) do |response|
        response.reply(t(:yourwelcome, subject: response.user.mention_name))
      end
      route(/^est[áa] (listo|servido) el almuerzo/i, help: help_msg(:lunch_served)) do
        message = t(:dinner_is_served)
        notify @assigner.winning_lunchers_list, message
      end
      route(/qu[ée] hay de postre/i, help: help_msg(:dessert)) do |response|
        response.reply(t(:"todays_dessert#{1 + rand(4)}"))
      end
      route(/tengo hambre/i) do |response|
        response.reply(t(:"hungry#{1 + rand(4)}"))
      end
      route(/qu[ée] hay de almuerzo/i, help: help_msg(:menu)) do |response|
        response.reply(t(:todays_lunch))
      end
      route(/por\sfavor\sconsidera\sa\s([^\s]+)\s(para|en) (el|los) almuerzos?/,
        command: true, help: help_msg(:consider_user)) do |response|
        karma_for_new_user = @karmanager.average_karma(@assigner.lunchers_list)
        mention_name = clean_mention_name(response.matches[0][0])
        success = @assigner.add_to_lunchers(mention_name)
        if success
          response.reply(t(:will_ask_daily, subject: mention_name))
          user = Lita::User.find_by_mention_name(mention_name)
          @karmanager.set_karma(user.id, karma_for_new_user)
          response.reply("Le asigne #{karma_for_new_user} a #{user.mention_name} con id #{user.id}")
          broadcast_to_channel("Se empezó a considerar a #{user.mention_name}. " +
            "Nuevo karma:  #{karma_for_new_user}", KARMA_AUDIT_CHANNEL)
        else
          response.reply(t(:already_considered, subject: mention_name))
        end
      end
      route(/por\sfavor\sconsid[ée]rame\s(para|en) los almuerzos/i,
        command: true, help: help_msg(:consider_me)) do |response|
        success = @assigner.add_to_lunchers(response.user.mention_name)
        if success
          response.reply(t(:will_ask_you_daily))
        else
          response.reply(t(:already_considered_you, subject: response.user.mention_name))
        end
      end
      route(/por\sfavor\sya\sno\sconsideres\sa\s([^\s]+)\s(para|en) (el|los) almuerzos?/i,
        command: true, help: help_msg(:not_consider_user)) do |response|
        mention_name = clean_mention_name(response.matches[0][0])
        @assigner.remove_from_lunchers(mention_name)
        response.reply(t(:thanks_for_answering))
        broadcast_to_channel("Se dejó de considerar a #{mention_name}", KARMA_AUDIT_CHANNEL)
      end
      route(/^s[íi]$|^hoy almuerzo aqu[íi]$/i,
        command: true, help: help_msg(:confirm_yes)) do |response|
        add_user_to_lunchers(response.user.mention_name)
        response.reply(get_current_lunchers_msg)
      end
      route(/no almuerzo/i, command: true, help: help_msg(:confirm_no)) do |response|
        remove_user_from_luncher_lists response.user.mention_name
        response.reply(t(:thanks_for_answering))
      end

      route(/tengo un invitado/i, command: true) do |response|
        if @assigner.add_to_winning_lunchers(response.user.mention_name) &&
            @assigner.add_to_winning_lunchers("invitado_de_#{response.user.mention_name}")
          response.reply(t(:friend_added, subject: response.user.mention_name))
        else
          response.reply('tu amigo no cabe wn')
        end
      end

      route(/tengo una invitada/i, command: true) do |response|
        response.reply('es rica?')
      end

      route(/qui[ée]nes almuerzan hoy/i, help: help_msg(:show_today_lunchers)) do |response|
        unless @assigner.already_assigned?
          response.reply("Aun no lo se pero van #{@assigner.current_lunchers_list.count} \
            interesados: #{@assigner.current_lunchers_list.join(', ')}")
          next
        end
        case @assigner.winning_lunchers_list.length
        when 0
          response.reply(t(:no_one_lunches))
        when 1
          response.reply(t(:only_one_lunches, subject: @assigner.winning_lunchers_list[0]))
        when 2
          response.reply(t(:dinner_for_two,
            subject1: @assigner.winning_lunchers_list[0],
            subject2: @assigner.winning_lunchers_list[1]))
        else
          response.reply(t(:current_lunchers_list,
            subject1: @assigner.winning_lunchers_list.length,
            subject2: @assigner.winning_lunchers_list.join(', ')))
        end
      end

      route(/qui[ée]n(es)? ((cooper(o|ó|aron))|(cag(o|ó|aron))|(qued(o|ó|aron)) afuera) ((del|con el) almuerzo)? (hoy)?\??/i,
        help: help_msg(:show_loosing_lunchers)) do |response|
        unless @assigner.already_assigned?
          response.reply("No lo se, pero van #{@assigner.current_lunchers_list.count} \
            interesados: #{@assigner.current_lunchers_list.join(', ')}")
          next
        end
        case @assigner.loosing_lunchers_list.length
        when 0
          response.reply('Nadie, estoy de buena hoy dia :)')
        else
          verb = ['perjudiqué a', 'me maletié a', 'cooperó', 'deje afuera a'].sample
          response.reply("Hoy #{verb} #{@assigner.loosing_lunchers_list.join(', ')}")
        end
      end

      route(/qui[ée]nes est[áa]n considerados para (el|los) almuerzos?\??/i,
        help: help_msg(:show_considered)) do |response|
        response.reply(@assigner.lunchers_list.join(', '))
      end

      route(/assignnow/i, command: true) do |response|
        assign_winners
        response.reply('did it boss')
      end

      route(/cu[áa]nto karma tengo\??/i, command: true) do |response|
        user_karma = @karmanager.get_karma(response.user.id)
        response.reply("Tienes #{user_karma} puntos de karma, mi padawan.")
      end

      route(/cu[áa]nto karma tiene ([^\s^?]+)\??/i, command: true) do |response|
        mention_name = clean_mention_name(response.matches[0][0])
        user = Lita::User.find_by_mention_name(mention_name)
        user_karma = @karmanager.get_karma(user.id)
        response.reply("@#{user.mention_name} tiene #{user_karma} puntos de karma.")
      end

      route(/(transfi[ée]r|d|su[ée]lt|p[áa]s)[ae]le (\d*)( ?karmas?)? a ([^\s]+)/i,
        command: true) do |response|
        giver = response.user
        amount = [response.matches[0][1].to_i, 1].max
        mention_name = clean_mention_name(response.matches[0][-1])
        destinatary = Lita::User.find_by_mention_name(mention_name)
        transfered = @karmanager.transfer_karma(giver.id, destinatary.id, amount)
        if transfered
          response.reply(
            "@#{giver.mention_name}, le has dado #{amount} de tus puntos de " +
            "karma a @#{destinatary.mention_name}."
          )
          broadcast_to_channel("@#{giver.mention_name}, le ha dado #{amount} punto/s de " +
            "karma a @#{destinatary.mention_name}.", KARMA_AUDIT_CHANNEL)
        else
          response.reply(
            "@#{giver.mention_name}, no se pudo transferir el karma"
          )
        end
      end

      route(/c[eé]dele mi puesto a ([^\s]+)/i, command: true) do |response|
        unless @assigner.remove_from_winning_lunchers(response.user.mention_name)
          response.reply('no puedes ceder algo que no tienes, amiguito')
          next
        end
        enters = clean_mention_name(response.matches[0][0])
        @assigner.add_to_winning_lunchers(enters)
        response.reply("tú te lo pierdes, comerá #{enters} por ti")
      end

      route(/.*/i, command: false) do |response|
        silenced_room = Lita::Room.find_by_name('lita-test')
        next unless silenced_room && response.room
        if quiet_time? && silenced_room.id == response.room.id
          user = Lita::User.find_by_mention_name('agustin')
          message = 'Estoy empezando a sugerir que evitemos hablar en #coffeebar entre las 10 y' \
          'las 12 del día para que la gente en la oficina pueda concentrarse. Las interrupciones' \
          ' hacen muy dificil trabajar! mira: http://www.paulgraham.com/makersschedule.html'
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      route(/^vend[oe] (mi|\s)? ?almuerzo( a | en )?([^\D]+)?( karma)?/i,
        command: true, help: help_msg(:sell_lunch)) do |response|
        user = response.user
        price = (response.matches[0].detect { |match| match.to_i > 0 } || 1).to_i
        unless winning_list.include?(user.mention_name)
          response.reply("@#{user.mention_name} #{t(:cant_sell)}")
          next
        end
        unless price == 1 || (@karmanager.get_karma(user.id) + price) < ENV.fetch('KARMA_LIMIT', 50).to_i
          price = 1
          response.reply("@#{user.mention_name} #{t(:cant_sell_high_price)}")
        end
        next unless @market.add_limit_order(user: user, type: 'ask', price: price)
        if transaction = @market.execute_transaction
          notify_transaction(transaction['buyer'], transaction['seller'], transaction['price'])
        else
          response.reply_privately(
            "@#{user.mention_name}, #{t(:selling_lunch, price: price)}"
          )
          broadcast_to_channel(
            "@#{user.mention_name}, #{t(:selling_lunch, price: price)}",
            COOKING_CHANNEL
          )
        end
      end

      route(/ya no (me )?vend(o|as)( (mi )?almuerzo)?/i,
        command: true, help: help_msg(:cancel_lunch_sell_order)) do |response|
        cancel_order(response, 'ask')
      end

      route(/ya no (me )?compr(o|es)( (un )?almuerzo)?/i,
        command: true, help: help_msg(:cancel_lunch_buy_order)) do |response|
        cancel_order(response, 'bid')
      end

      route(/^c(o|ó)mpr(o|ame|a)? (un )?almuerzo( a | en )?([^\D]+)?( karma)?/i,
        command: true, help: help_msg(:buy_lunch)) do |response|
        user = response.user
        price = (response.matches[0].detect { |match| match.to_i > 0 } || 1).to_i
        if winning_list.include?(user.mention_name)
          response.reply("@#{user.mention_name} #{t(:cant_buy)}")
          next
        end
        next unless @market.add_limit_order(user: user, type: 'bid', price: price)
        if transaction = @market.execute_transaction
          notify_transaction(transaction['buyer'], transaction['seller'], transaction['price'])
        else
          response.reply_privately(
            "@#{user.mention_name}, #{t(:buying_lunch, price: price)}"
          )
          broadcast_to_channel(
            "@#{user.mention_name}, #{t(:buying_lunch, price: price)}",
            COOKING_CHANNEL
          )
        end
      end

      route(/apuesto ([^\D]+)( puntos)?( de karma)?/i, command: true) do |response|
        wager = response.matches[0][0].to_i
        unless @assigner.set_wager(response.user.mention_name, wager)
          response.reply("no puedes apostar tanto karma, amiguito")
          next
        end
        add_user_to_lunchers(response.user.mention_name)
        response.reply("apostaste #{wager} puntos de karma")
      end

      route(/reparte tu karma/i, command: true) do |response|
        days_since = (Date.today - @emitter.last_emission_date).to_i
        if days_since > EMISSION_INTERVAL_DAYS
          users = @assigner.lunchers_list.map do |mention_name|
            Lita::User.find_by_mention_name(mention_name)
          end
          emitted_karma = @emitter.emit(users)
          response.reply(t(:karma_emitted, karma_amount: emitted_karma))
          broadcast_to_channel(t(:karma_emitted, karma_amount: emitted_karma), COOKING_CHANNEL)
        else
          response.reply(t(:karma_not_emitted, days_remaining: EMISSION_INTERVAL_DAYS - days_since))
        end
      end

      route(/quiero pedir/i, command: true, help: help_msg(:want_delivery)) do |response|
        mention_msg = mention_in_thread(response.user.mention_name, get_winners_msg_timestamp)
        response.reply(t(:food_delivery_link,
          channel_code: mention_msg['channel'], timestamp: mention_msg['ts'].remove('.')))
      end

      route(/(show me the money)|(mu(e|é)stra(me)? la lista( de karma)?)/i,
        command: true, help: help_msg(:karma_list)) do |response|
        response.reply_privately(karma_list_message)
      end

      route(/c(o|ó)mo est(a|á) el mercado/i, command: true, help: help_msg(:order_book)) do |response|
        response.reply(order_book_message)
      end

      def assign_winners
        if @assigner.winning_lunchers_list.count >= MAX_LUNCHERS
          @assigner.do_the_assignment
        end
        @market.reset_limit_orders
        if @assigner.winning_lunchers_list.count > 0
          announce_winners
        end
      end

      def karma_list_message
        karma_list = @karmanager.karma_list(@assigner.lunchers_list).sort_by { |_, karma| -karma }
        entries = karma_list.map do |mention_name, karma|
          t(:karma_list_entry, mention_name: mention_name, karma: karma)
        end.join("\n")
        t(:karma_list, entries: entries)
      end

      def order_book_message
        ask_orders = @market.ask_orders.reverse
        bid_orders = @market.bid_orders
        ask_entries = ask_orders.map { |order| order_book_entry_message(order) }.join("\n")
        bid_entries = bid_orders.map { |order| order_book_entry_message(order) }.join("\n")
        ask_entries = ask_orders.any? ? ask_entries : ':tumbleweed:'
        bid_entries = bid_orders.any? ? bid_entries : ':tumbleweed:'
        t(:order_book, ask_entries: ask_entries, bid_entries: bid_entries)
      end

      def order_book_entry_message(order)
        user = Lita::User.find_by_id(order['user_id'])
        t(
          :order_book_entry,
          user: user.mention_name,
          action: order['type'] == 'ask' ? 'vendiendo a': 'comprando a',
          price: order['price']
        )
      end

      def add_user_to_lunchers(mention_name)
        @assigner.add_to_current_lunchers(mention_name)
        @assigner.add_to_winning_lunchers(mention_name) if @assigner.already_assigned?
      end

      def broadcast_to_channel(message, channel)
        target = Source.new(room: channel)
        robot.send_message(target, message)
      end

      def quiet_time?
        ((1..5).cover? Time.now.wday) &&
          (Time.now.hour >= ENV['QUIET_START_HOUR'].to_i) &&
          (Time.now.hour <= ENV['QUIET_END_HOUR'].to_i)
      end

      def clean_mention_name(mention_name)
        mention_name.delete('@') if mention_name
      end

      def refresh
        lunchers_list = @assigner.lunchers_list
        @assigner.reset_lunchers
        @karmanager.reset_daily_transfers(
          lunchers_list.map { |name| Lita::User.find_by_mention_name(name).id }
        )
        @market.reset_limit_orders
        lunchers_list.each do |luncher|
          ask_luncher(luncher)
        end
      end

      def lunch_answer_cb(payload)
        user_id = payload["user"]["id"]
        target = Source.new(user: User.find_by_id(user_id))
        original_message = payload["original_message"]["text"]

        if payload["actions"][0]["value"] == "yes"
          add_user_to_lunchers(target.user.mention_name)
          reply_msg = get_current_lunchers_msg
        else
          remove_user_from_luncher_lists target.user.mention_name
          reply_msg = t(:thanks_for_answering)
        end

        http.post(
          payload["response_url"],
          { "text": "#{original_message}\n_#{reply_msg}_" }.to_json
        )
      end

      def ask_luncher(luncher)
        user = Lita::User.find_by_mention_name(luncher)
        message = t(:question, day: @assigner.weekday_name_plus(1), subject: luncher)
        attachment = get_lunch_buttons

        if user
          @slack_client.chat_postMessage(
            channel: user.id,
            as_user: true,
            text: message,
            attachments: [attachment]
          )
        end
      end

      def notify(list, message)
        list.shuffle.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      def announce_waggers(waggers)
        case waggers.inject(0, :+)
        when 1..MAX_LUNCHERS
          broadcast_to_channel(t(:low_wagger, waggers: waggers.join(', ')),
            COOKING_CHANNEL)
        when MAX_LUNCHERS..20
          broadcast_to_channel(t(:mid_wagger, waggers: waggers.join(', ')),
            COOKING_CHANNEL)
        when 20..40
          broadcast_to_channel(t(:high_wagger, waggers: waggers.join(', ')),
            COOKING_CHANNEL)
        else
          broadcast_to_channel(t(:crazy_wagger, waggers: waggers.join(', ')),
            COOKING_CHANNEL)
        end
      end

      def announce_winners
        notify(@assigner.winning_lunchers_list, 'Yeah baby, almuerzas con nosotros!')
        winners_msg = broadcast_to_channel(
          t(:current_lunchers_list,
            subject1: @assigner.winning_lunchers_list.length,
            subject2: @assigner.winning_lunchers_list.shuffle.join(', ')),
          COOKING_CHANNEL
        )
        comment_in_thread(t(:food_delivery), winners_msg['ts'])
        save_winners_msg_timestamp(winners_msg['ts'])
        waggers = @assigner.wager_hash(@assigner.winning_lunchers_list).values.sort.reverse
        announce_waggers(waggers)
        notify(@assigner.loosing_lunchers_list, t(:current_lunchers_too_many))
      end

      def announce_karma_list
        broadcast_to_channel(karma_list_message, KARMA_AUDIT_CHANNEL)
      end

      def comment_in_thread(msg, thread_timestamp)
        @slack_client.chat_postMessage(
          channel: COOKING_CHANNEL.delete('#'),
          text: msg,
          thread_ts: thread_timestamp,
          as_user: true
        )
      end

      def mention_in_thread(user, thread_timestamp)
        comment_in_thread("<@#{user}>", thread_timestamp)
      end

      def create_schedule # rubocop:disable Metric/MethodLength
        scheduler = Rufus::Scheduler.new
        scheduler.cron(ENV['ASK_CRON']) do
          refresh
        end
        scheduler.cron(ENV['ANNOUNCE_WINNERS_CRON']) do
          assign_winners
        end
        scheduler.cron(ENV['PERSIST_CRON']) do
          @assigner.persist_winning_lunchers
          @assigner.persist_wagers
        end
        scheduler.cron(ENV.fetch('COUNTS_CRON')) do
          count_lunches
        end
        scheduler.cron(ENV.fetch('KARMA_LIST_CRON')) do
          announce_karma_list
        end
      end

      def cancel_order(response, order_type)
        user = response.user
        order = @market.find_order(order_type, user.id)
        action = order_type == 'bid' ? 'buying' : 'selling'
        if order.nil?
          response.reply(t("not_#{action}_lunch".to_sym))
          return
        end
        @market.remove_order(order)
        response.reply_privately("@#{user.mention_name}, #{t("#{action}_lunch_cancelled".to_sym)}")
        broadcast_to_channel(
          "@#{user.mention_name}, #{t("#{action}_lunch_cancelled")}",
          COOKING_CHANNEL
        )
      end

      def winning_list
        @winning_list ||= @assigner.winning_lunchers_list
      end

      def notify_transaction(buyer_user, seller_user, price)
        seller_message = "@#{seller_user.mention_name}, #{t(:sold_lunch)}"
        buyer_message = "@#{buyer_user.mention_name}, #{t(:bought_lunch)}"
        robot.send_message(Source.new(user: seller_user), seller_message) if seller_user
        robot.send_message(Source.new(user: buyer_user), buyer_message) if buyer_user
        broadcast_to_channel(
          t(
            :transaction,
            subject1: buyer_user.mention_name,
            subject2: seller_user.mention_name,
            price: price
          ),
          COOKING_CHANNEL
        )
      end

      def count_lunches
        counter = Lita::Services::LunchCounter.new
        counts = counter.persist_lunches_count
        return unless counts
        user = Lita::User.find_by_mention_name(ENV.fetch('LUNCH_ADMIN', 'jesus'))
        message = t(
          :announce_count,
          subject: user.mention_name,
          month: counts[0],
          count1: counts[1],
          count2: counts[2],
          count3: counts[3]
        )
        robot.send_message(Source.new(user: user), message) if user
      end

      def save_winners_msg_timestamp(timestamp)
        redis.set('winners_msg_timestamp', timestamp)
      end

      def get_winners_msg_timestamp
        redis.get('winners_msg_timestamp')
      end

      def get_lunch_buttons
        {
          callback_id: "lunch_answer",
          actions: [{
            name: "lunch_answer",
            text: "Si",
            type: "button",
            value: "yes",
            style: "good"
          }, {
            name: "lunch_answer",
            text: "No",
            type: "button",
            value: "no",
            style: "danger"
          }],
          fallback: "Hubo un problema. Intenta respondiendo a mano."
        }
      end

      def get_current_lunchers_msg
        lunchers = @assigner.current_lunchers_list.length
        case lunchers
        when 1
          t(:current_lunchers_one)
        else
          t(:current_lunchers_some, subject: lunchers)
        end
      end

      def remove_user_from_luncher_lists(mention_name)
        @assigner.remove_from_current_lunchers mention_name
        @assigner.remove_from_winning_lunchers mention_name
      end

      Lita.register_handler(self)
    end
  end
end
