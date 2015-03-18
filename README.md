# Redmine Email to Markdown

## Description

Convert html to markdown and use inline images from incoming emails.

## Installation

To install the plugin clone the repo from github and migrate the database:

```
cd /path/to/redmine/
git clone git://github.com/dkalachov/redmine_email_to_markdown.git plugins/redmine_email_to_markdown
bundle
rake redmine:plugins:migrate RAILS_ENV=production
```

## Compatibility

The latest version of this plugin is only tested with Redmine 2.6-stable.

