require 'spec_helper'
require 'redis'
require 'date'


describe Lita::Handlers::Outage_Counter, lita_handler: true do
  it { is_expected.to route_command('when was the last outage').to(:last_outage) }
  it { is_expected.to route_command('the site went down').to(:new_outage) }
  it { is_expected.to route_command('what is the average outage').to(:average) }
  it { is_expected.to route_command('what is the high score').to(:high_score) }
  it { is_expected.to route_command('reset the outage counter').to(:reset) }
  it { is_expected.to route_command('there was a new outage 5 days ago').to(:outage_manual_reset)}
  it { is_expected.to route_command('remove outage date 2016-2-23').to(:remove_outage_date)}
  it { is_expected.to route_command('show all outage dates').to(:show_all_outages)}

  describe '#reset' do
    context 'when starting a new outage count from the beginning' do
      it 'resets the countage counter to 0 and deletes all data from previous counts' do
        send_command('reset the outage counter')
        expect(replies.last).to eq('All collected data deleted and new outage counter set up.')
      end
    end
  end

  describe '#show_all_outages' do
    context 'when user wants to see all outages dates' do
      let(:dates_toString){
        [(Date.today - 10).to_s, (Date.today - 20).to_s, (Date.today - 30).to_s]
      }
      let(:sorted_dates){
        dates_toString.map{|str_date| Date.parse(str_date)}.sort.map(&:to_s)
      }
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 30 days ago')
        send_command('there was a new outage 20 days ago')
        send_command('there was a new outage 10 days ago')
      end
      it 'returns all the past outage dates' do
        send_command('show all outage dates')
        expect(replies.last).to eq("List of current outage dates in order from oldest to most recent \n" +
          sorted_dates.join("\n"))
      end
    end
  end

  describe 'outage_manual_reset' do
    context 'when needing to manually reset a outage counter from a missed date' do
      let(:num_of_days){
        5
      }
      let(:new_outage_date){
        (Date.today - num_of_days).to_s
      }
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 5 days ago')
      end
      it 'logs the new outage according to the number of days specified' do
        expect(replies.last).to eq('The new outage has been logged for ' + new_outage_date + ', which was ' +num_of_days.to_s + ' days ago.')
      end
    end
  end

  describe '#last_outage' do
    context 'when there has been no outages yet' do
      before do
        send_command('reset the outage counter')
      end
      it 'returns a message validating that there are not outages currently' do
       send_command('when was the last outage')
       expect(replies.last).to eq('There has not been an outage yet.')
      end
    end
    context 'when called to show last outage date' do
      let(:today){
        Date.today
      }
      let(:last_outage){
        today - 4
      }
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 4 days ago')
      end
      it 'replies with the number of days passed and the date of last outage' do
        send_command('when was the last outage')
        expect(replies.last).to eq('The last outage was on ' + last_outage.to_s + ', which was 4 days ago.')
      end
    end
  end

  describe '#new_outage' do
    context 'when a new outage occurs' do
      let(:today){
        Date.today
      }
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 3 days ago')
      end
      it 'resets the outage counter back to 0 and saves the number of days without outage to key "outage_dates". ' do
        send_command('the site went down')
        expect(replies.last).to eq('The outage counter has reset to ' + today.to_s + '.')
      end
    end
  end

  describe '#average' do
    context 'when calling for average of days without an average' do
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 30 days ago')
        send_command('there was a new outage 20 days ago')
        send_command('there was a new outage 10 days ago')
      end
      it 'returns the average number of days without an outage' do
        send_command('what is the average outage')
        expect(replies.last).to eq('The average number of days without an outage is 10.0 days.')
      end
    end
  end

  describe '#high_score' do
    context 'when looking for the highest number of days without an outage' do
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 30 days ago')
        send_command('there was a new outage 20 days ago')
        send_command('there was a new outage 15 days ago')
      end
      it 'returns the higest recorded number of days without an outage' do
        send_command('what is the high score')
        expect(replies.last).to eq('The longest streak of days without an outage is 15 days.')
      end
    end
  end

  describe '#remove_outage_date' do
    context 'when user mistypes for having a missed outage date' do
      let(:removed_date){
        (Date.today - 9).to_s
      }
      before do
        send_command('reset the outage counter')
        send_command('there was a new outage 30 days ago')
        send_command('there was a new outage 20 days ago')
        send_command('there was a new outage 15 days ago')
      end
      it 'deletes the certain date from outage_dates by specifying the days since today' do
        send_command('remove outage date ' + removed_date)
        expect(replies.last).to eq(removed_date + ' has been deleted from the date database.')
      end
    end
  end
end