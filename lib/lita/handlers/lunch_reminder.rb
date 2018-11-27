# coding: utf-8

module Lita
  module Handlers
    class LunchReminder < Handler
      MAX_LUNCHERS = ENV.fetch('MAX_LUNCHERS').to_i
      MIN_LUNCHERS = MAX_LUNCHERS - 4

      on :loaded, :load_on_start

      def initialize(robot)
        super
        @karmanager = Lita::Services::Karmanager.new(redis)
        @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
        @market = Lita::Services::MarketManager.new(redis, @assigner, @karmanager)
      end

      def self.help_msg(route)
        { "lunch-reminder: #{t("help.#{route}.usage")}" => t("help.#{route}.description") }
      end

      def load_on_start(_payload)
        create_schedule
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
            "Nuevo karma:  #{karma_for_new_user}", '#karma-audit')
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
        broadcast_to_channel("Se dejó de considerar a #{mention_name}", '#karma-audit')
      end
      route(/^s[íi]$|^hoy almuerzo aqu[íi]$/i,
        command: true, help: help_msg(:confirm_yes)) do |response|
        add_user_to_lunchers(response.user.mention_name)
        lunchers = @assigner.current_lunchers_list.length
        case lunchers
        when 1
          response.reply(t(:current_lunchers_one))
        else
          response.reply(t(:current_lunchers_some, subject: lunchers))
        end
      end
      route(/no almuerzo/i, command: true, help: help_msg(:confirm_no)) do |response|
        @assigner.remove_from_current_lunchers response.user.mention_name
        response.reply(t(:thanks_for_answering))
        @assigner.remove_from_winning_lunchers response.user.mention_name
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
        @assigner.do_the_assignment
        announce_winners
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

      route(/transfi[ée]rele karma a ([^\s]+)/i, command: true) do |response|
        giver = response.user
        mention_name = clean_mention_name(response.matches[0][0])
        destinatary = Lita::User.find_by_mention_name(mention_name)
        @karmanager.transfer_karma(giver.id, destinatary.id, 1)
        response.reply(
          "@#{giver.mention_name}, le has dado uno de tus puntos de " +
          "karma a @#{destinatary.mention_name}."
        )
        broadcast_to_channel("@#{giver.mention_name}, le ha dado un punto de " +
          "karma a @#{destinatary.mention_name}.", '#karma-audit')
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
        if quiet_time? && Lita::Room.find_by_name('lita-test').id == response.room.id
          user = Lita::User.find_by_mention_name('agustin')
          message = 'Estoy empezando a sugerir que evitemos hablar en #coffeebar entre las 10 y' \
          'las 12 del día para que la gente en la oficina pueda concentrarse. Las interrupciones' \
          ' hacen muy dificil trabajar! mira: http://www.paulgraham.com/makersschedule.html'
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      route(/vend[oe] (mi|\s)? ?almuerzo/i,
        command: true, help: help_msg(:sell_lunch)) do |response|
        user = response.user
        new_order = create_order(user, 'ask')
        unless winning_list.include?(user.mention_name)
          response.reply("@#{user.mention_name} #{t(:cant_sell)}")
          next
        end
        order = @market.add_limit_order(new_order)
        return unless order
        transaction = execute_transaction
        if transaction
          notify_transaction(transaction['buyer'], transaction['seller'])
        else
          response.reply_privately(
            "@#{user.mention_name}, #{t(:selling_lunch)}"
          )
          broadcast_to_channel("@#{user.mention_name}, #{t(:selling_lunch)}", '#cooking')
        end
      end

      route(/c(o|ó)mpr(o|ame|a)? (un )?almuerzo/i,
        command: true, help: help_msg(:buy_lunch)) do |response|
        user = response.user
        new_order = create_order(user, 'bid')
        if winning_list.include?(user.mention_name)
          response.reply("@#{user.mention_name} #{t(:cant_buy)}")
          next
        end
        order = @market.add_limit_order(new_order)
        return unless order
        transaction = execute_transaction
        if transaction
          notify_transaction(transaction['buyer'], transaction['seller'])
        else
          response.reply_privately(
            "@#{user.mention_name}, #{t(:buying_lunch)}"
          )
          broadcast_to_channel("@#{user.mention_name}, #{t(:buying_lunch)}", '#cooking')
        end
      end

      route(/apuesto ([^\D]+) puntos( de karma)?/i, command: true) do |response|
        wager = response.matches[0][0].to_i
        unless @assigner.set_wager(response.user.mention_name, wager)
          response.reply("no puedes apostar tanto karma, amiguito")
          next
        end
        add_user_to_lunchers(response.user.mention_name)
        response.reply("apostaste #{wager} puntos de karma")
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
        @assigner.reset_lunchers
        @market.reset_limit_orders
        @assigner.lunchers_list.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          message = t(:question, day: @assigner.weekday_name_plus(1), subject: luncher)
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      def notify(list, message)
        list.shuffle.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      def announce_waggers(waggers)
        case waggers.sum
        when 1..MAX_LUNCHERS
          broadcast_to_channel(t(:low_wagger, waggers: waggers.join(', ')),
            '#cooking')
        when MAX_LUNCHERS..20
          broadcast_to_channel(t(:mid_wagger, waggers: waggers.join(', ')),
            '#cooking')
        when 20..40
          broadcast_to_channel(t(:high_wagger, waggers: waggers.join(', ')),
            '#cooking')
        else
          broadcast_to_channel(t(:crazy_wagger, waggers: waggers.join(', ')),
            '#cooking')
        end
      end

      def announce_winners
        notify(@assigner.winning_lunchers_list, 'Yeah baby, almuerzas con nosotros!')
        broadcast_to_channel(
          t(:current_lunchers_list,
            subject1: @assigner.winning_lunchers_list.length,
            subject2: @assigner.winning_lunchers_list.shuffle.join(', ')),
          '#cooking'
        )
        waggers = @assigner.wager_hash(@assigner.winning_lunchers_list).values
        announce_waggers(waggers)
        notify(@assigner.loosing_lunchers_list, t(:current_lunchers_too_many))
      end

      def create_schedule
        scheduler = Rufus::Scheduler.new
        scheduler.cron(ENV['ASK_CRON']) do
          refresh
          scheduler.in(ENV['WAIT_RESPONSES_SECONDS'].to_i) do
            @assigner.do_the_assignment
            announce_winners if @assigner.winning_lunchers_list.count >= MIN_LUNCHERS
          end
        end
        scheduler.cron(ENV['PERSIST_CRON']) do
          @assigner.persist_winning_lunchers
        end
      end

      def create_order(user, type)
        {
          id: SecureRandom.uuid,
          user_id: user.id,
          type: type,
          created_at: Time.now
        }.to_json
      end

      def winning_list
        @winning_list ||= @assigner.winning_lunchers_list
      end

      def execute_transaction
        executed_orders = @market.execute_transaction
        return unless executed_orders
        ask_order = executed_orders['ask']
        bid_order = executed_orders['bid']
        seller_user = Lita::User.find_by_id(ask_order['user_id'])
        buyer_user = Lita::User.find_by_id(bid_order['user_id'])
        {
          'buyer' => buyer_user,
          'seller' => seller_user,
          'timestamp' => Time.now,
          'bid_order' => bid_order,
          'ask_order' => ask_order
        }
      end

      def notify_transaction(buyer_user, seller_user)
        seller_message = "@#{seller_user.mention_name}, #{t(:sold_lunch)}"
        buyer_message = "@#{buyer_user.mention_name}, #{t(:bought_lunch)}"
        robot.send_message(Source.new(user: seller_user), seller_message) if seller_user
        robot.send_message(Source.new(user: buyer_user), buyer_message) if buyer_user
        broadcast_to_channel(
          t(:transaction, subject1: buyer_user.mention_name, subject2: seller_user.mention_name),
          '#cooking'
        )
      end

      Lita.register_handler(self)
    end
  end
end
