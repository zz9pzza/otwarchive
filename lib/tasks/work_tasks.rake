namespace :work do
  desc "Purge drafts created more than a month ago"
  task(:purge_old_drafts => :environment) do
    count = Work.purge_old_drafts
    puts "Unposted works (#{count}) created more than one month ago have been purged"
  end

  desc "create missing hit counters"
  task(:missing_stat_counters => :environment) do
    Work.find_each do |work|
      counter = work.stat_counter
      unless counter
        counter = StatCounter.create(:work => work, :hit_count => 1)
      end
    end
  end

  desc "Push recommendation jobs in to resque"
  task(:create_recomendation_work => :environment) do
    Work.find_each do |work|
      work.async(:recomended_works_update_cache)
    end
  end

end
