Given /^all search indexes are updated$/ do
  [Work, Bookmark, Pseud, Tag].each do |klass|
    # TIRE
    klass.import
    klass.tire.index.refresh
    #
    # Elasticsearch
    if $elasticsearch.indices.exists? index: "ao3_test_#{klass.to_s.downcase}s"
      $elasticsearch.indices.delete index: "ao3_test_#{klass.to_s.downcase}s"
    end

    "#{klass}Indexer".constantize.create_index

    indexer = "#{klass}Indexer".constantize.new(klass.all.pluck(:id))
    indexer.index_documents rescue nil
  end
end

Given /^the (\w+) indexes are updated$/ do |model|
  # TIRE
  model.classify.constantize.import
  model.classify.constantize.tire.index.refresh
  #
  # Elasticsearch
  if $elasticsearch.indices.exists? index: "ao3_test_#{model}s"
    $elasticsearch.indices.delete index: "ao3_test_#{model}s"
  end

  "#{model.classify}Indexer".constantize.create_index

  indexer = "#{model.classify}Indexer".constantize.new(model.classify.constantize.all.pluck(:id))
  indexer.index_documents
end

Given /^the (\w+) indexes are reindexed$/ do |model|
  $elasticsearch.indices.refresh index: "ao3_test_#{model}s"
end

Given /^all search indexes are reindexed$/ do
end
