require 'rubygems'
require 'sinatra'
require 'curdbee'
require 'rack-flash'

use Rack::Flash
set :logging, true
set :sessions, true
set :public, File.dirname(__FILE__) + '/public'

get '/' do
end

get '/checkout' do
 erb :checkout
end 

post '/checkout' do
 begin

   @valid_coupon_codes = ["Awesome", "Super", "002211"]
   # set the API key and subdomain for your CurdBee account.
   CurdBee::Config.api_key = "QBikEJ1gATy_G4xHljs6"
   CurdBee::Config.subdomain = "laktek"

   # create client
   @client = CurdBee::Client.new(:name => params['client']['name'],
                                 :email => params['client']['email'],
                                 :address => params['client']['street_address'],
                                 :city => params['client']['city'],
                                 :province => params['client']['state'],  
                                 :zip_code => params['client']['zip'],  
                                 :country => params['client']['country'],  
                                 :phone => params['client']['phone']  
                                )
   unless @client.create
     flash[:error] = "Required contact details are missing or invalid."
     redirect '/checkout'
   end

   # add line items
   @line_items = []
   params['item'].each do |item|
    if item['quantity'].to_i > 0 
      @line_items << {:name_and_description => item['name'], :quantity => item['quantity'], :price => item['unit_price']} 
    end
   end

   # create invoice 
   @invoice = CurdBee::Invoice.new(
              :date => Date.today,
              :due_date => (Date.today + 2),
              :client_id => @client.id,
              :summary => "Purchase from My Awesome store",
              :line_items_attributes => @line_items, 
              :notes => "We will ship the items within 2 days of receiving the payment"
            )
   # apply discount if there's a valid coupoun code
   if(@valid_coupon_codes.include?(params['coupon_code']))
     @invoice.discount = "10%"
   end

   # lets assume flat rate shipping
   @invoice.shipping = "5.00"

   # create the invoice
   unless @invoice.create
     flash[:error] = "Unable to create the invoice. Please enter your order again."
     redirect '/checkout'
   end

   # send invoice
   if @invoice.deliver({ 'recipients' => [@client.email] })
      #reload the invoice
      @invoice = CurdBee::Invoice.show(@invoice.id)
      redirect @invoice.permalink
    else
     flash[:error] = "Failed to send the invoice. Did you enter a valid email?"
     redirect '/checkout'
    end
  rescue => e
    flash[:error] = "Following issue occured when processing your order - #{e}"
   redirect '/checkout'
  end
end
