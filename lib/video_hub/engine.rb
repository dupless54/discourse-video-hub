# frozen_string_literal: true

module ::VideoHub
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace VideoHub
    config.autoload_paths << File.join(config.root, "lib")
  end
end
