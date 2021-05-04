# frozen_string_literal: true

module Warren
  # Railtie for automatic configuration in Rails apps. Reduces the need to
  # modify the application when adding Warren.
  # @see https://api.rubyonrails.org/classes/Rails/Railtie.html
  class Railtie < Rails::Railtie
    config.to_prepare do
      Warren.load_configuration
    end
  end
end
