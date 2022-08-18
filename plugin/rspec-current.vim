function! MyFunction()
  ruby <<RUBY
    require_relative 'ruby/rspec-current.rb'
    Current.new.context
RUBY
endfunction
