function! MyFunction()
  ruby <<RUBY
  require_relative "#{__dir__}/ruby/rspec-current.rb"
    Current.new.context
RUBY
endfunction
