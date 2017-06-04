# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/component/droplet'
require 'java_buildpack/component/environment_variables'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the integraton of the JavaMemoryAssistant to inject the agent in the JVM.
    class JavaMemoryAssistantAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_javaagent @droplet.sandbox + jar_name

        @droplet.java_opts.add_system_property 'jma.enabled', 'true'
        @droplet.java_opts.add_system_property 'jma.heap_dump_name', name_pattern

        add_system_prop_if_config_present 'check_interval', 'jma.check_interval'
        add_system_prop_if_config_present 'max_frequency', 'jma.max_frequency'

        @droplet.java_opts.add_system_property 'jma.log_level', log_level

        (@configuration['thresholds'] || {}).each do |key, value|
          @droplet.java_opts.add_system_property "jma.thresholds.#{key}", value.to_s
        end
      end

      protected

      def supports?
        true
      end

      # (see JavaBuildpack::Component::VersionedDependencyComponent#jar_name)
      def jar_name
        "java-memory-assistant-#{@version}.jar"
      end

      private

      def name_pattern
        "#{@application.details['space_id'][0, 6]}_" \
          "#{@application.details['application_name']}_" \
          '%env:CF_INSTANCE_INDEX%_' \
          '%ts:yyyyMMddmmssSS%_' \
          '%env:CF_INSTANCE_GUID%' \
          '.hprof'
      end

      def add_system_prop_if_config_present(config_entry, system_property_name, quote_value = false)
        return unless @configuration[config_entry]

        config_value = @configuration[config_entry]
        config_value = '"' + config_value + '"' if quote_value

        @droplet.java_opts.add_system_property(system_property_name, config_value)
      end

      def log_level
        actual_log_level = @configuration['log_level'] || ENV['JBP_LOG_LEVEL'] || 'ERROR'

        mapped_log_level = log_level_mapping[actual_log_level.upcase]

        raise "Invalid value of the 'log_level' property: '#{actual_log_level}'" unless mapped_log_level

        mapped_log_level
      end

      def log_level_mapping
        {
          'DEBUG' => 'DEBUG',
          'WARN' => 'WARNING',
          'INFO' => 'INFO',
          'ERROR' => 'ERROR',
          'FATAL' => 'ERROR'
        }
      end

    end
  end
end
