admin = User.find_or_create_by!(email_address: "admin@sitio.local") do |user|
  user.password = "password123"
  user.role = :admin
end

active_school = School.find_or_create_by!(title: "Escola Ativa") do |school|
  school.description = "Escola de exemplo ativa e visível na loja."
  school.url = "https://example.com/escola-ativa"
end

inactive_school = School.find_or_create_by!(title: "Escola Inativa") do |school|
  school.description = "Escola de exemplo desativada."
end
inactive_school.deactivate(user: admin) unless inactive_school.deactivated?

concealed_school = School.find_or_create_by!(title: "Escola Oculta na Loja") do |school|
  school.description = "Ativa no app, oculta na loja Wix."
end
concealed_school.conceal_in_store(user: admin) unless concealed_school.store_concealed?

active_school.trips.find_or_create_by!(title: "Viagem Ativa") do |trip|
  trip.description = "Viagem de exemplo ativa."
  trip.default_expected_amount_minor = 15_000
end

active_school.trips.find_or_create_by!(title: "Viagem Expirada na Loja") do |trip|
  trip.description = "Deve ser ocultada pelo job horário."
  trip.expiration_date = 1.day.ago
end

puts "Seeded admin=#{admin.email_address}, schools=#{School.count}, trips=#{Trip.count}"
