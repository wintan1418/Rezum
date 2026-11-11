# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 8.0 framework defaults upgrade.
# (Rails' `app:update` only generates the file for the current version, so this
# one was added by hand from the Rails 8.0 template when upgrading 7.2 -> 8.1.)
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `8.0`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# Specifies whether `to_time` methods preserve the UTC offset of their receivers or preserves the timezone.
# If set to `:zone`, `to_time` methods will use the timezone of their receivers.
# If set to `:offset`, `to_time` methods will use the UTC offset.
# If `false`, `to_time` methods will convert to the local system UTC offset instead.
#
# Enabled: the app runs with config.time_zone = "UTC", so this is behaviour-neutral
# and silences the Rails 8.x deprecation for the old behaviour.
#++
Rails.application.config.active_support.to_time_preserves_timezone = :zone

###
# When both `If-Modified-Since` and `If-None-Match` are provided by the client
# only consider `If-None-Match` as specified by RFC 7232 Section 6.
# If set to `false` both conditions need to be satisfied.
#
# Enabled: the app does not use fresh_when/stale?, so this only affects
# Rack::ETag/ConditionalGet behaviour on full-page responses (RFC-correct).
#++
Rails.application.config.action_dispatch.strict_freshness = true

###
# Set a global Regexp timeout of 1 second. Protects against ReDoS.
#
# Left disabled for now: the app runs many regexes over large AI-generated and
# uploaded resume text; enable after checking long inputs don't hit the timeout.
#++
# Regexp.timeout ||= 1
