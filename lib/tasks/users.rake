namespace :users do
  desc "Create a Linkletter account: bin/rails users:create EMAIL=you@example.com"
  task create: :environment do
    require "io/console"
    email = ENV["EMAIL"].presence || abort("Usage: bin/rails users:create EMAIL=you@example.com")
    print "Password (min 12 chars): "
    password = $stdin.noecho(&:gets).to_s.chomp
    puts
    user = User.create(email_address: email, password: password)
    if user.persisted?
      puts "Created #{user.email_address}"
    else
      abort user.errors.full_messages.to_sentence
    end
  end
end
