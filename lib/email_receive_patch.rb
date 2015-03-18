#encoding: utf-8

require 'sanitize'
require 'reverse_markdown'
require_dependency 'mail_handler'

module MailHandlerInlineImagesPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :cleaned_up_text_body, :inline_images
    end
  end

  module InstanceMethods

    def cleaned_up_text_body_with_inline_images
      return @cleaned_up_text_body unless @cleaned_up_text_body.nil?

      parts = if (html_parts = email.all_parts.select {|p| p.mime_type == 'text/html'}).present?
                html_parts
              elsif (text_parts = email.all_parts.select {|p| p.mime_type == 'text/plain'}).present?
                text_parts
              else
                [email]
              end

      parts.reject! do |part|
        part.header[:content_disposition].try(:disposition_type) == 'attachment'
      end

      plain_text_body = parts.map { |p| decode_part_body(p) }.join("\r\n")

      # strip html tags and remove doctype directive
      if parts.any? {|p| p.mime_type == 'text/html'}
        is_textile = Setting.text_formatting == 'textile'
        plain_text_body.gsub!(FIND_IMG_SRC_PATTERN) do
          filename = nil
          $2.match(/^cid:(.+)/) do |m|
            filename = email.all_parts.find {|p| p.cid == m[1]}.filename
          end
          is_textile ? " !#{filename}! " : " ![](#{filename}) "
        end

        redmine_from = Setting.mail_from
        redmine_email_seen = false

        base_config = {
          :elements => %w[ h1 h2 h3 h4 h5 h6 em strong i b blockquote code a hr li ol ul table tr th td p br ],
          :attributes => {
              'a'          => %w[href],
          },
          :protocols => {
              'a'          => {'href' => ['ftp', 'http', 'https', 'mailto', :relative]},
          },
        }

        plain_text_body = Sanitize.fragment(plain_text_body, Sanitize::Config.merge(
            base_config,
            :transformers => [
                lambda do |env|
                  return unless env[:node_name] == 'style' # total delete for style element (bug with outlook output)
                  # || env[:node_name] == 'blockquote' # remove contents of quotes
                  node = env[:node]
                  node.unlink
                end,

                lambda do |env|
                  node = env[:node]
                  if redmine_email_seen
                    node.unlink
                  else
                    if node.text?
                      if node.to_s.match(redmine_from)
                        redmine_email_seen = true
                        node.parent.unlink
                      end
                    end
                  end
                end,

                lambda do |env|
                  # first tr's td -> th
                  return unless env[:node_name] == 'tr'
                  node = env[:node]
                  if node == node.parent.first_element_child
                    node.children.each do |child|
                      if child.name == 'td'
                        child.name = 'th'
                      end
                    end
                  end
                end,

                lambda do |env|
                  # remove p's inside th, td (damned Outlook)
                  return unless env[:node_name] == 'th' || env[:node_name] == 'td'
                  env[:node].children.each do |child|
                    Sanitize.node!(child)
                  end
                end,
            ],
        ))
        plain_text_body = ReverseMarkdown.convert plain_text_body
        plain_text_body.gsub!(/^([[:space:]]|&nbsp;)+$/, "")
        plain_text_body.gsub!(/^·/, "-")
        plain_text_body.gsub!(/^o/, "  -")
        plain_text_body.gsub!(/^([[:space:]])*(\d+\.|-)([[:space:]]|&nbsp;)+(.*)$/, "\\1\\2 \\4")
        plain_text_body.gsub!(/[\n]{3,}/, "\n\n")
        plain_text_body = cleanup_body(plain_text_body << "\n") # \n fixes cleanup bug
        regex = is_textile ? /^[ \t]+(![^!]+!)/ : /^[ \t]+(!\[\]\([^)]+\))/
        plain_text_body.gsub!(regex, '\1') # fix for images
      end
      @cleaned_up_text_body = plain_text_body.strip
    end


    private

    def decode_part_body(p)
      body_charset = Mail::RubyVer.respond_to?(:pick_encoding) ?
          Mail::RubyVer.pick_encoding(email.html_part.charset).to_s : p.charset
      Redmine::CodesetUtil.to_utf8(p.body.decoded, body_charset)
    end
  end
end

MailHandler.send(:include, MailHandlerInlineImagesPatch)

