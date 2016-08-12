require 'lita'
require 'redis'
require 'date'

module Lita
  module Handlers
    class Outage_Counter < Handler
      route(/reset the outage counter/, :reset,
            command: true, help: {'reset the outage counter' => 'Deletes all previous records '})
      route(/when was the last outage/, :last_outage,
            command: true, help: {'when was the last outage' => 'Shows the last date the site was down, along with the count'})
      route(/the site went down/, :new_outage,
            command: true, help: {'the site went down' => 'Resets the outage counter to start today'})
      route(/what is the average outage/, :average,
            command: true, help: {'what is the average outage' => 'Shows the team\'s average streak without outage.'})
      route(/what is the high score/, :high_score,
            command: true, help: {'what is the high score' => 'Shows the highest record of no-outages.'})
      route(/there was a new outage ((\d)+) days ago/, :outage_manual_reset,
            command: true, help: {'there was a new outage N days ago' => 'Allows user to reset the outage counter according to how many days since passed'})
      route(/remove outage date (\d{4}-\d{1,2}-\d{1,2})/, :remove_outage_date,
            command: true, help: {'remove outage date (date)' => 'Allows user to delete that certain date that they may have mistyped'})
      route(/show all outage dates/, :show_all_outages,
            command: true, help: {'show all outage dates' => 'Lists all the outage dates'})

      def reset(response)
        redis.del("last_outage")
        redis.del("outage_dates")
        response.reply('All collected data deleted and new outage counter set up.')
      end

      def show_all_outages(response)
      sorted_dates = (redis.smembers("outage_dates")).map{|str_date| Date.parse(str_date)}.sort.map(&:to_s)
      response.reply("List of current outage dates in order from oldest to most recent \n" +
          sorted_dates.join("\n")
      )
      end

      def outage_manual_reset(response)
        num_days_passed = response.matches[0][0].to_i
        date_missed_outage= Date.today - num_days_passed
        redis.sadd("outage_dates", date_missed_outage)
        sorted_dates = (redis.smembers("outage_dates")).map{|str_date| Date.parse(str_date)}.sort
        redis.set("last_outage", sorted_dates[sorted_dates.size - 1])
        response.reply('The new outage has been logged for ' + date_missed_outage.to_s + ', which was ' + num_days_passed.to_s + ' days ago.')
      end

      def last_outage(response)
        if redis.get("last_outage").nil?
          response.reply('There has not been an outage yet.')
        else
          date_last_outage = Date.parse(redis.get("last_outage"))
          days_since_last_outage = (Date.today - date_last_outage).to_i
          response.reply('The last outage was on ' + date_last_outage.to_s + ', which was ' + days_since_last_outage.to_s + ' days ago.')
        end
      end

      def new_outage(response)
        redis.sadd("outage_dates", Date.today)
        redis.set("last_outage", Date.today)
        response.reply('The outage counter has reset to ' + Date.today.to_s + '.')
      end

      def average(response)
        sorted_dates = (redis.smembers("outage_dates")).map{|str_date| Date.parse(str_date)}.sort
        sorted_dates.push(Date.today)
        if sorted_dates[0] == Date.today
          avg = 0
        else
          num_days = sorted_dates.each_cons(2).map{|a, b| (b-a)}
          avg = num_days.inject(:+).to_f/num_days.size
        end
        response.reply('The average number of days without an outage is ' + avg.to_s + ' days.')
      end

      def remove_outage_date(response)
        date_to_delete = Date.parse(response.matches[0][0])
        redis.srem("outage_dates", date_to_delete)
        response.reply(date_to_delete.to_s + ' has been deleted from the date database.')
      end

      def high_score(response)
        sorted_dates = (redis.smembers("outage_dates")).map{|str_date| Date.parse(str_date)}.sort
        sorted_dates.push(Date.today)
        num_days = sorted_dates.each_cons(2).map{|a, b|(b-a)}
        max = num_days.max.to_i
        response.reply('The longest streak of days without an outage is ' + max.to_s + ' days.')
      end

      Lita.register_handler(self)
    end
  end
end