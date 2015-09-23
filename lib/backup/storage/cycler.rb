# encoding: utf-8

module Backup
  module Storage
    module Cycler
      class Error < Backup::Error; end

      private

      # Adds the current package being stored to the YAML cycle data file
      # and will remove any old package file(s) when the storage limit
      # set by #keep is exceeded.
      def cycle!
        Logger.info 'Cycling Started...'

        to_be_deleted = []
        packages = yaml_load.unshift(package)

        if keep.is_a?(Date) || keep.is_a?(Time)
          to_be_deleted = packages.select { |p| p.time_as_object < k.to_time }
        else
          excess = packages.count - keep.to_i
          to_be_deleted = packages.pop(excess) if excess > 0
        end

        to_be_deleted.each { |package| delete_package package }

        yaml_save(packages)
      end

      def delete_package(package)
        begin
          remove!(package) unless package.no_cycle
        rescue => err
          Logger.warn Error.wrap(err, <<-EOS)
            There was a problem removing the following package:
            Trigger: #{package.trigger} :: Dated: #{package.time}
            Package included the following #{ package.filenames.count } file(s):
            #{ package.filenames.join("\n") }
          EOS
        end
      end

      # Returns path to the YAML data file.
      def yaml_file
        @yaml_file ||= begin
          filename = self.class.to_s.split('::').last
          filename << "-#{ storage_id }" if storage_id
          File.join(Config.data_path, package.trigger, "#{ filename }.yml")
        end
      end

      # Returns stored Package objects, sorted by #time descending (oldest last).
      def yaml_load
        if File.exist?(yaml_file) && !File.zero?(yaml_file)
          YAML.load_file(yaml_file).sort_by!(&:time).reverse!
        else
          []
        end
      end

      # Stores the given package objects to the YAML data file.
      def yaml_save(packages)
        FileUtils.mkdir_p(File.dirname(yaml_file))
        File.open(yaml_file, 'w') do |file|
          file.write(packages.to_yaml)
        end
      end

    end
  end
end
