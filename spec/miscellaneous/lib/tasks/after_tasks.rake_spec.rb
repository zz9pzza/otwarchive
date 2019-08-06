require "spec_helper"

describe "rake After:reset_word_counts" do
  let(:en) { Language.find_by(short: "en") }
  let(:en_work) { create(:posted_work, language: en, chapter_attributes: { content: "Nice ride, Gloria!" }) }

  context "when there are multiple languages" do
    let(:es) { create(:language, short: "es") }
    let(:es_work) { create(:posted_work, language: es, chapter_attributes: { content: "Así pasa la gloria del mundo." }) }

    before do
      # Screw up the word counts
      en_work.update_column(:word_count, 3000)
      es_work.update_column(:word_count, 4000)
    end

    it "updates only works in the specified language" do
      subject.invoke("es")

      en_work.reload
      es_work.reload

      expect(en_work.word_count).to eq(3000)
      expect(es_work.word_count).to eq(6)
    end
  end

  context "when a work has multiple chapters" do
    let(:chapter) { create(:chapter, work: en_work, posted: true, position: 2, authors: en_work.authors, content: "A few more words never hurt.") }

    before do
      # Screw up the word counts
      chapter.update_column(:word_count, 9001)
      en_work.first_chapter.update_column(:word_count, 100_000)
      en_work.update_column(:word_count, 60)
    end

    it "updates word counts for each chapter and for the work" do
      subject.invoke("en")

      en_work.reload

      expect(en_work.word_count).to eq(9)
      expect(en_work.first_chapter.word_count).to eq(3)
      expect(en_work.last_chapter.word_count).to eq(6)
    end
  end
end

describe "rake After:unhide_invited_works" do
  let(:invited_anonymous_collection) { create(:anonymous_collection) }
  let(:invited_unrevealed_collection) { create(:unrevealed_collection) }
  let(:anonymous_collection) { create(:anonymous_collection) }
  let(:unrevealed_collection) { create(:unrevealed_collection) }
  let(:other_collection) { create(:collection) }
  let(:invited_anonymous_unrevealed_collection) { create(:anonymous_unrevealed_collection)}
  let(:invited_anonymous_work) { create(:posted_work, collections: [invited_anonymous_collection]) }
  let(:invited_unrevealed_work) { create(:posted_work, collections: [invited_unrevealed_collection]) }
  let(:normal_work) { create(:posted_work, collections: [other_collection]) }
  let(:invited_anonymous_unrevealed_work) { create(:posted_work, collections: [invited_anonymous_unrevealed_collection]) }
  let(:anonymous_work) { create(:posted_work, collections: [anonymous_collection]) }
  let(:unrevealed_work) { create(:posted_work, collections: [unrevealed_collection]) }

  context "When invited works are incorrectly anonymous or unrevealed" do
    before do
      # Screw up collection items
      invited_anonymous_work.collection_items.first.update_columns(user_approval_status: 0)
      invited_unrevealed_work.collection_items.first.update_columns(user_approval_status: 0)
      invited_anonymous_unrevealed_work.collection_items.first.update_columns(user_approval_status: 0)
    end

    it "updates the anonymous and unrevealed status of invited work" do
      subject.invoke
      normal_work.reload
      invited_anonymous_work.reload
      invited_unrevealed_work.reload
      invited_anonymous_unrevealed_work.reload
      unrevealed_work.reload
      anonymous_work.reload
      expect(normal_work.unrevealed?).to be(false)
      expect(normal_work.anonymous?).to be(false)
      expect(invited_anonymous_work.unrevealed?).to be(false)
      expect(invited_anonymous_work.anonymous?).to be(false)
      expect(invited_unrevealed_work.unrevealed?).to be(false)
      expect(invited_unrevealed_work.anonymous?).to be(false)
      expect(invited_anonymous_unrevealed_work.anonymous?).to be(false)
      expect(invited_anonymous_unrevealed_work.unrevealed?).to be(false)
      expect(anonymous_work.unrevealed?).to be(false)
      expect(anonymous_work.anonymous?).to be(true)
      expect(unrevealed_work.unrevealed?).to be(true)
      expect(unrevealed_work.anonymous?).to be(false)
    end
  end
end
