# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__)

require 'bundler'
Bundler.require(:default, (ENV["RACK_ENV"]|| 'development').to_sym)

#NEO4J_POOL = ConnectionPool.new(:size => 10, :timeout => 3) { Neography::Rest.new }
