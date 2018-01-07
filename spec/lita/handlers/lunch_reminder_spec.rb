require "spec_helper"
require 'pry'

describe Lita::Handlers::LunchReminder, lita_handler: true do
  it "responds to invite announcement" do
    usr = Lita::User.create(123, name: "carlos")
    send_message("@lita tengo un invitado", as: usr)
    expect(replies.last).to eq("Perfecto @carlos, anoté a tu invitado como invitado_de_carlos.")
  end
  it "responds to user" do
    usr = Lita::User.create(124, name: "armando")
    send_message("@lita tengo un invitado", as: usr)
    expect(replies.last).to eq("Perfecto @armando, anoté a tu invitado como invitado_de_armando.")
  end
  it "responds to user" do
    usr = Lita::User.create(124, name: "armando")
    send_message("@lita tengo un invitado", as: usr)
    send_message("quienes almuerzan hoy?", as: usr)
    expect(replies.last).to match("no lo se")
  end
  it "responds that invitee does not fit" do
    ['armando', 'luis', 'peter'].each do |name|
      usr = Lita::User.create(124, name: name)
      send_message("@lita tengo un invitado", as: usr)
    end
    expect(replies.last).to match("no cabe")
  end
  it "does not allow a user to give his place before he has it" do
    usr = Lita::User.create(124, name: "armando")
    send_message("@lita hoy almuerzo aquí", as: usr)
    send_message("@lita cédele mi puesto a patricio", as: usr)
    expect(replies.last).to match("algo que no tienes")
  end
end
