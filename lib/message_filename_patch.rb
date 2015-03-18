require_dependency 'mail/message'

module MessageFilenamePatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :filename, :no_spaces
    end
  end

  module InstanceMethods
    def filename_with_no_spaces
      filename = filename_without_no_spaces
      filename.gsub!(/\s+/, '-') if filename
      filename
    end
  end
end

Mail::Message.send(:include, MessageFilenamePatch)
