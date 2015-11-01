require 'slack-ruby-bot'

module PomodoroBot
  class App < SlackRubyBot::App
  end

  class Start < SlackRubyBot::Commands::Base
    command 'start' do |client, data, _match|
      client.message text: 'started', channel: data.channel
    end
  end
end

SlackRubyBot.configure do |config|
  config.aliases = ['pom','pombot']
end

PomodoroBot::App.instance.run