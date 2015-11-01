require 'slack-ruby-bot'

module PomodoroBot
  class App < SlackRubyBot::App
  end

  class Start < SlackRubyBot::Commands::Base
    @@status = 'stopped'
    @@phase = 'work'
    @@work_default = 25
    @@break_default = 5
    @@time_remaining = { 'work' => @@work_default, 'break' => @@break_default }
    @@time_started = nil
    @@user = ''
    @@channel = 'pomodoro' # Channel to which pomodoro bot will post responses
    @@status_channel = 'pomodoro_status' # Channel in which pomodoro will re-trigger itself

    def self.set_user(data_user)
      users = `curl $"https://slack.com/api/users.list?token=#{ENV['SLACK_API_TOKEN']}"`
      users_json = JSON.parse(users)
      user = users_json['members'].detect{|u| u["id"] == data_user}
      @@user = user['name']
    end

    def self.status
      @@status
    end

    def self.user
      @@user
    end

    def self.channel
      @@channel
    end

    def self.status_channel
      @@status_channel
    end

    def self.toggle_phase
      @@phase = (@@phase == 'work' ? 'break' : 'work')
    end

    def self.start_timer
      @@time_started = Time.now
    end

    def self.pause_timer
      # Subtract elapsed time from original duration
      @@time_remaining[@@phase] -= (Time.now - @@time_started)
    end

    def self.post_message(message, channel)
      `curl --data "#{message}" $"https://cyrusinnovation.slack.com/services/hooks/slackbot?token=#{ENV['SLACK_SERVICE_HOOK_TOKEN']}&channel=%23#{channel}"`
    end

    def self.post_status
      self.post_message(self.status, self.channel)
    end

    def self.prompt_phase
      self.post_message("#{self.user} #{self.phase} now!", self.channel)
    end

    def self.phase_complete?(current_time)
      current_time - @@time_started >= @@time_remaining[@@phase]
    end

    command 'start' do |client, data, _match|
      self.set_user(data.user)
      self.start_timer
      # Reply to channel to acknowledge command
      @@status = 'started'
      self.post_status
      self.prompt_phase
      # Start timer process
      self.post_message("pom status", self.status_channel)
    end
  
    command 'status' do |client, data, _match|
      if @@status == 'started'
        current_time = Time.now
        if self.phase_complete?(current_time)
          self.toggle_phase
          self.prompt_phase
          @@time_started = current_time
        end
        self.post_message("pom status", self.status_channel)
        sleep(10)
      end
    end

    command 'pause' do |client, data, _match|
      @@status = 'paused'
      self.pause_timer
      self.post_status
    end

    command 'restart' do |client, data, _match|
      self.start_timer
      @@status = 'started'
      self.post_status
      self.post_message("pom status", self.status_channel)
    end

    command 'stop' do |client, data, _match|
      #stop callbacks and reset variables
      @@status = 'stopped'
      @@phase = 'work'
      @@time_remaining = { 'work' => @@work_default, 'break' => @@break_default }
      @@time_started = nil

      self.post_status
    end
  end
end

SlackRubyBot.configure do |config|
  config.aliases = ['pom','pombot']
  config.allow_message_loops = true
end

PomodoroBot::App.instance.run