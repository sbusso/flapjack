require 'spec_helper'
require 'flapjack/gateways/sms_twilio'

describe Flapjack::Gateways::SmsTwilio, :logger => true do

  let(:lock)  { double(Monitor) }
  let(:redis) { double(Redis)}

  let(:config) { {'account_sid'  => 'the_account_sid',
                  'auth_token'   => 'the_auth_token',
                  'from'         => 'the_from_address'
                 }
               }

  let(:time) { Time.new(2013, 10, 31, 13, 45) }
  let(:time_str) { Time.at(time).strftime('%-d %b %H:%M') }

  let(:queue) { double(Flapjack::RecordQueue) }
  let(:alert) { double(Flapjack::Data::Alert) }

  let(:check)  { double(Flapjack::Data::Check) }

  before(:each) do
    allow(Flapjack).to receive(:redis).and_return(redis)
  end

  it "sends an SMS message" do
    req = stub_request(:post, "https://api.twilio.com/2010-04-01/Accounts/the_account_sid/Messages.json").
      with(:headers => {'Authorization' => ['the_account_sid', 'the_auth_token']}).
      to_return(:status => 201)

    expect(Flapjack::RecordQueue).to receive(:new).with('sms_twilio_notifications',
      Flapjack::Data::Alert).and_return(queue)

    medium = double(Flapjack::Data::Medium)
    expect(medium).to receive(:address).and_return('555-555555')

    expect(alert).to receive(:medium).and_return(medium)

    expect(alert).to receive(:id).twice.and_return('123456789')
    expect(alert).to receive(:rollup).and_return(nil)

    expect(alert).to receive(:type).and_return('recovery')
    expect(alert).to receive(:type_sentence_case).and_return('Recovery')
    expect(alert).to receive(:summary).and_return('smile')

    expect(alert).to receive(:state_title_case).and_return('OK')
    expect(alert).to receive(:time).and_return(time.to_i)

    expect(check).to receive(:name).and_return('example.com:ping')
    expect(alert).to receive(:check).and_return(check)

    expect(lock).to receive(:synchronize).and_yield
    expect(queue).to receive(:foreach).and_yield(alert)
    expect(queue).to receive(:wait).and_raise(Flapjack::PikeletStop)

    expect(redis).to receive(:quit)

    sms_gw = Flapjack::Gateways::SmsTwilio.new(:lock => lock,
                                               :config => config)
    expect { sms_gw.start }.to raise_error(Flapjack::PikeletStop)
    expect(req).to have_been_requested
  end

  it "truncates a long message" do
    long_summary = 'Four score and seven years ago our ' +
      'fathers brought forth on this continent, a new nation, conceived in ' +
      'Liberty, and dedicated to the proposition that all men are created equal.'

    body = {
      'To'   => '555-555555',
      'From' => 'the_from_address',
      'Body' => "Recovery: 'example.com:ping' is " +
                "OK at #{time_str}, Four score and seven years ago " +
                'our fathers brought forth on this continent, a new ' +
                'nation, conceived in L...'}

    req = stub_request(:post, "https://api.twilio.com/2010-04-01/Accounts/the_account_sid/Messages.json").
      with(:body  => body,
           :headers => {'Authorization' => ['the_account_sid', 'the_auth_token']}).
      to_return(:status => 200)

    medium = double(Flapjack::Data::Medium)
    expect(medium).to receive(:address).and_return('555-555555')

    expect(alert).to receive(:medium).and_return(medium)

    expect(alert).to receive(:id).twice.and_return('123456789')
    expect(alert).to receive(:rollup).and_return(nil)

    expect(alert).to receive(:type).and_return('recovery')
    expect(alert).to receive(:type_sentence_case).and_return('Recovery')
    expect(alert).to receive(:summary).and_return(long_summary)

    expect(alert).to receive(:state_title_case).and_return('OK')
    expect(alert).to receive(:time).and_return(time.to_i)

    expect(check).to receive(:name).and_return('example.com:ping')
    expect(alert).to receive(:check).and_return(check)

    expect(Flapjack::RecordQueue).to receive(:new).with('sms_twilio_notifications',
      Flapjack::Data::Alert).and_return(queue)

    expect(lock).to receive(:synchronize).and_yield
    expect(queue).to receive(:foreach).and_yield(alert)
    expect(queue).to receive(:wait).and_raise(Flapjack::PikeletStop)

    expect(redis).to receive(:quit)

    sms_gw = Flapjack::Gateways::SmsTwilio.new(:lock => lock,
                                               :config => config)
    expect { sms_gw.start }.to raise_error(Flapjack::PikeletStop)
    expect(req).to have_been_requested
  end

  it "does not send an SMS message with an invalid config" do
    expect(Flapjack::RecordQueue).to receive(:new).with('sms_twilio_notifications',
      Flapjack::Data::Alert).and_return(queue)

    medium = double(Flapjack::Data::Medium)
    expect(medium).to receive(:address).and_return('555-555555')

    expect(alert).to receive(:medium).and_return(medium)

    expect(alert).to receive(:id).and_return('123456789')
    expect(alert).to receive(:rollup).and_return(nil)

    expect(alert).to receive(:type).and_return('recovery')
    expect(alert).to receive(:type_sentence_case).and_return('Recovery')
    expect(alert).to receive(:summary).and_return('smile')

    expect(alert).to receive(:state_title_case).and_return('OK')
    expect(alert).to receive(:time).and_return(time.to_i)

    expect(check).to receive(:name).and_return('example.com:ping')
    expect(alert).to receive(:check).and_return(check)

    expect(lock).to receive(:synchronize).and_yield
    expect(queue).to receive(:foreach).and_yield(alert)
    expect(queue).to receive(:wait).and_raise(Flapjack::PikeletStop)

    expect(redis).to receive(:quit)

    sms_gw = Flapjack::Gateways::SmsTwilio.new(:lock => lock,
                                               :config => config.reject {|k, v| k == 'auth_token'})

    expect { sms_gw.start }.to raise_error(Flapjack::PikeletStop)

    expect(WebMock).not_to have_requested(:post,
      "https://api.twilio.co/2010-04-01/Accounts/the_account_sid/Messages.json")
  end

end
