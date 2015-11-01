require 'slack-ruby-bot'

module PomodoroBot
  class App < SlackRubyBot::App
  end

  class Start < SlackRubyBot::Commands::Base
    @@status = 'unstarted'
    @@phase = 'work'
    @@work_default = 25
    @@break_default = 5
    @@time_remaining = { 'work' => @@work_default, 'break' => @@break_default }
    @@time_started = nil
    @@user = ''

    command 'start' do |client, data, _match|
      @@time_started = Time.now
      @@status = 'running'
      users = `curl $"https://slack.com/api/users.list?token=#{ENV['SLACK_API_TOKEN']}"`
      users_json = JSON.parse(users)
      user = users_json['members'].detect{|u| u["id"] == data.user}
      @@user = user['name']
      # Reply to channel to acknowledge command
      `curl --data "started" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
      `curl --data "#{@@user} work now!" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
      # Start timer process
      `curl --data "pom status" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro_status"`
    end
  
    command 'status' do |client, data, _match|
      if @@status == 'running'
        current_time = Time.now
        if current_time - @@time_started >= @@time_remaining[@@phase]
          if @@phase == 'work'
            # Switch to break
            @@phase = 'break'
            `curl --data "#{@@user} break now!" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
          elsif @@phase == 'break'
            # Back to work
            @@phase = 'work'
            `curl --data "#{@@user} work now!" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
          end
          @@time_started = current_time
        end
        `curl --data "pom status" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro_status"`
        sleep(10)
      end
    end

    command 'pause' do |client, data, _match|
      @@status = 'paused'
      # Subtract elapsed time from original duration
      @@time_remaining[@@phase] -= (Time.now - @@time_started)
      `curl --data "paused" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
    end

    command 'restart' do |client, data, _match|
      @@time_started = Time.now
      @@status = 'running'
      `curl --data "restarted" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
      `curl --data "pom status" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro_status"`
    end

    command 'stop' do |client, data, _match|
      #stop callbacks and reset variables
      @@status = 'unstarted'
      @@phase = 'work'
      @@work_default = 25
      @@break_default = 5
      @@time_remaining = { 'work' => @@work_default, 'break' => @@break_default }
      @@time_started = nil

      `curl --data "stopped" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23pomodoro"`
    end
  end
end

SlackRubyBot.configure do |config|
  config.aliases = ['pom','pombot']
  config.allow_message_loops = true
end

PomodoroBot::App.instance.run