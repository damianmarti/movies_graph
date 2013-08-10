# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__)

require 'lib/movies'
require 'movies_app'

map '/' do
  run App
end