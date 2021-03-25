# frozen_string_literal: true

module Warren
  # Railtie for automatic configuration in Rails apps. Reduces the need to
  # modify the application when adding Warren.
  # @see https://api.rubyonrails.org/classes/Rails/Railtie.html
  class Railtie < Rails::Railtie
    # initializer "railtie.configure_rails_initialization" do

    # end
    config.to_prepare do
      config = begin
        Rails.application.config_for(:warren)
      rescue RuntimeError => e
        warn <<~WARN
          🐇 WARREN CONFIGURATION ERROR
          #{e.message}
          Use `warren config` to generate a basic configuration file
        WARN
        exit 1
      end
      Warren.setup(config.deep_symbolize_keys.slice(:type, :config))
    end
  end
end
