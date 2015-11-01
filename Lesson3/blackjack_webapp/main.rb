require 'rubygems'
require 'sinatra'
require 'pry'

set :sessions, true

BLACKJACK = 21
DEALER_STAY = 17

helpers do
  def calculate_total(cards)
    hand_values = cards.map{|values| values[1]}

    total = 0
    hand_values.each do |value|
      if value == "ace"
        total += 11
      else
        total += value.to_i == 0 ? 10 : value.to_i
      end
    end

    hand_values.select{|value| value == "ace"}.count.times do
      break if total <= BLACKJACK
      total -= 10
    end

    total
  end

  def card_image(card)
    suit = card[0]
    value = card[1]

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def loser!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @error = "<strong>Dealer wins.</strong> #{msg}"
    if broke?
      redirect '/game_over'
    end
  end

  def winner!(msg)
    raise_chip_total(session[:player_bet])
    @play_again = true
    @show_hit_or_stay_buttons = false
    @success = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @success = "<strong>This round is a tie.</strong> #{msg}"
  end

  def raise_chip_total(wager)
    wager *= 2
    session[:chip_total] += wager
  end

  def broke?
    session[:chip_total] <= 0
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game/player_bet'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
    @error = "Name is required to continue."
    halt erb :new_player
  end

  session[:player_name] = params[:player_name]
  session[:chip_total] = 500
  redirect '/game/player_bet'
end

get '/game' do
  session[:turn] = session[:player_name]
  
  suits = %w(hearts diamonds clubs spades)
  values = %w(2 3 4 5 6 7 8 9 10 jack queen king ace)
  session[:deck] = suits.product(values).shuffle!

  # deal cards
  session[:dealers_cards] = []
  session[:players_cards] = []
  session[:dealers_cards] << session[:deck].pop
  session[:players_cards] << session[:deck].pop
  session[:dealers_cards] << session[:deck].pop
  session[:players_cards] << session[:deck].pop

  player_total = calculate_total(session[:players_cards])
  if player_total == BLACKJACK
    session[:player_bet] *=  2
    winner!("Congratulations, you hit Blackjack!")
  end

  erb :game
end

get '/game/player_bet' do
  erb :player_bet
end

post '/game/player_bet' do
  session[:player_bet] = params[:wager]

  if session[:player_bet].empty?
    @error = "You must enter a wager to continue."
    halt erb :player_bet
  elsif session[:player_bet].to_i.to_s != session[:player_bet]
    @error = "Please use whole numbers only."
    halt erb :player_bet
  elsif  session[:player_bet].to_i > session[:chip_total]
    @error = "You can't bet more than you have."
    halt erb :player_bet
  else
    session[:player_bet] = session[:player_bet].to_i
    session[:chip_total] -= session[:player_bet]
    redirect '/game'
  end
end

post '/game/player/hit' do
  session[:players_cards] << session[:deck].pop

  player_total = calculate_total(session[:players_cards])
  if player_total > BLACKJACK
    loser!("Busted!! Sorry you lose this round")
  end

  erb :game
end

post '/game/player/stay' do
  @success = "You have chosen to stay with a total of
  #{calculate_total(session[:players_cards])}."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false

  # decision tree
  dealer_total = calculate_total(session[:dealers_cards])

  if dealer_total == BLACKJACK && session[:dealers_cards].count == 2
    loser!("Sorry, the dealer has blackjack.")
  elsif dealer_total > BLACKJACK
    winner!("The dealer busted at #{dealer_total}!")
  elsif dealer_total >= DEALER_STAY
    #dealer_stays
    redirect '/game/compare'
  else
    #dealer_hits
    @show_dealer_hit_button = true
  end

  erb :game
end

post '/game/dealer/hit' do
  session[:dealers_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  player_total = calculate_total(session[:players_cards])
  dealer_total = calculate_total(session[:dealers_cards])

  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and the
      dealer stayed at #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and the
      dealer stayed at #{dealer_total}.")
  else
    session[:chip_total] += session[:player_bet]
    tie!("You and the dealer both stayed at #{player_total}.")
  end

  erb :game
end

get '/game_over' do
  erb :game_over
end
