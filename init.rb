require 'email_receive_patch'
require 'message_filename_patch'

Redmine::Plugin.register :redmine_email_to_markdown do
  name 'Redmine Email to Markdown plugin'
  author 'Dmitriy Kalachev'
  description 'Convert html to markdown and use inline images from incoming emails.'
  version '0.1'
  url 'http://github.com/dkalachov/redmine_email_to_markdown'
  author_url 'http://dkalachov.com'
end
