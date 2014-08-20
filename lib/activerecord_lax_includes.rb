module ActiveRecordLaxIncludes
  module Preloader
    def self.included(base)
      base.class_eval do
        alias_method :grouped_records_default, :grouped_records
        alias_method :grouped_records, :grouped_records_with_lax_include

        alias_method :preload_hash_default, :preload_hash
        alias_method :preload_hash, :preload_hash_with_lax_include
      end
    end

    def preload_hash_with_lax_include(association)
      association.each do |parent, child|
        ActiveRecord::Associations::Preloader.new(records, parent, preload_scope).run
        
        rec = records
        if lax_includes_enabled?
          rec = filtered_records_by_reflection(parent)
        end
        ActiveRecord::Associations::Preloader.new(rec.map { |record| record.send(parent) }.flatten, child).run
      end
    end

    def grouped_records_with_lax_include(association)
      rec = records
      if lax_includes_enabled?
        rec = filtered_records_by_reflection(association)
      end
      
      h = {}
      rec.each do |record|
        assoc = record.association(association)
        klasses = h[assoc.reflection] ||= {}
        (klasses[assoc.klass] ||= []) << record
      end
      h
    end

    def filtered_records_by_reflection(association)
      records.select do |record|
        record.class.reflections[association].present?
      end
    end

    def lax_includes_enabled?
      result = Thread.current[:active_record_lax_includes_enabled]
      if result.nil?
        result = Rails.configuration.respond_to?(:active_record_lax_includes_enabled) &&
                    Rails.configuration.active_record_lax_includes_enabled
      end
      result
    end
  end

  module BaseHelper
    def lax_includes
      Thread.current[:active_record_lax_includes_enabled] = true
      yield
    ensure
      Thread.current[:active_record_lax_includes_enabled] = false
    end
  end
end

require 'active_record'

ActiveRecord::Associations::Preloader.send(:include, ActiveRecordLaxIncludes::Preloader)
ActiveRecord.send(:extend, ActiveRecordLaxIncludes::BaseHelper)
