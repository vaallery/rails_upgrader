require "rails"
require "rails_erd"
require "rails_erd/domain"

module RailsUpgrader
  class CLI
    attr_reader :domain

    def self.call
      new.upgrade
    end

    def initialize
      puts "Preloading environment..."
      preload_environment
      puts "Preloading relationships..."
      @domain = RailsERD::Domain.generate
    end

    def upgrade
      puts "Upgrading Rails..."
      upgrade_strong_params!
      puts "Rails is upgraded!"
    end

    private

    def upgrade_strong_params
      result = domain.entities.map do |entity|
        RailsUpgrader::StrongParams.new(entity).generate_method if entity.model
      end.join

      File.open("all_strong_params.rb", "w") { |f| f.write(result) }
    end

    def upgrade_strong_params!
      domain.entities.each do |entity|
        next unless entity.model
        entity_to_upgrade = RailsUpgrader::StrongParams.new(entity)

        unless File.file?(entity_to_upgrade.controller_path)
          puts "Skipping #{entity.name}"
          next
        end

        next if entity_to_upgrade.already_upgraded?

        begin
          entity_to_upgrade.update_controller_content!
          entity_to_upgrade.update_model_content!
        rescue => e
          puts e.message
          puts e.backtrace
          next
        end
      end
    end

    def preload_environment
      require "#{Dir.pwd}/config/environment"
      Rails.application.eager_load!

      if Rails.application.respond_to?(:config) && Rails.application.config
        rails_config = Rails.application.config
        if rails_config.respond_to?(:eager_load_namespaces)
          rails_config.eager_load_namespaces.each(&:eager_load!)
        end
      end
    end
  end
end
