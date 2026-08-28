# frozen_string_literal: true

describe VideoHub::Video do
  let(:user) { Fabricate(:user) }

  def base_attributes
    {
      user: user,
      provider: "youtube",
      external_id: "dQw4w9WgXcQ",
      canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      kind: "landscape",
      status: "pending",
      title: "Example video",
      author_name: "Example creator",
    }
  end

  it "accepts a bounded pending canonical video before Topic/Post mapping" do
    video = described_class.new(base_attributes)

    expect(video).to be_valid
    expect(video.topic_id).to be_nil
    expect(video.post_id).to be_nil
    expect(video.published_at).to be_nil
  end

  it "requires an author when a new video record is created" do
    video = described_class.new(base_attributes.merge(user: nil))

    expect(video).not_to be_valid
    expect(video.errors[:user]).to be_present
  end

  it "restricts provider, kind, status, duration and bounded metadata values" do
    video =
      described_class.new(
        base_attributes.merge(
          provider: "vimeo",
          kind: "square",
          status: "hidden",
          duration_seconds: -1,
          title: "T" * (described_class::TITLE_MAX_LENGTH + 1),
          author_name: "A" * (described_class::AUTHOR_MAX_LENGTH + 1),
        ),
      )

    expect(video).not_to be_valid
    expect(video.errors[:provider]).to be_present
    expect(video.errors[:kind]).to be_present
    expect(video.errors[:status]).to be_present
    expect(video.errors[:duration_seconds]).to be_present
    expect(video.errors[:title]).to be_present
    expect(video.errors[:author_name]).to be_present
  end

  it "requires Topic and root Post mapping to be assigned as a pair" do
    topic = Fabricate(:topic, user: user)
    video = described_class.new(base_attributes.merge(topic: topic))

    expect(video).not_to be_valid
    expect(video.errors[:base]).to be_present
  end

  it "rejects a reply Post as the canonical root Post mapping" do
    topic = Fabricate(:topic, user: user)
    Fabricate(:post, topic: topic, user: user)
    reply_post = Fabricate(:post, topic: topic, user: user)
    video = described_class.new(base_attributes.merge(topic: topic, post: reply_post))

    expect(reply_post.post_number).to be > 1
    expect(video).not_to be_valid
    expect(video.errors[:post_id]).to be_present
  end

  it "requires published records to have Topic/root Post mapping and published_at" do
    incomplete = described_class.new(base_attributes.merge(status: "published"))

    expect(incomplete).not_to be_valid
    expect(incomplete.errors[:status]).to be_present

    topic = Fabricate(:topic, user: user)
    root_post = Fabricate(:post, topic: topic, user: user)
    complete =
      described_class.new(
        base_attributes.merge(
          status: "published",
          topic: topic,
          post: root_post,
          published_at: Time.zone.now,
        ),
      )

    expect(root_post.post_number).to eq(1)
    expect(complete).to be_valid
  end

  it "keeps canonical provider identity unique at both model and database layers" do
    described_class.create!(base_attributes)
    duplicate = described_class.new(base_attributes)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:external_id]).to be_present

    index =
      described_class
        .connection
        .indexes(:video_hub_videos)
        .find { |candidate| candidate.columns == %w[provider external_id] }

    expect(index).to be_present
    expect(index.unique).to eq(true)
  end

  it "keeps Topic and Post mappings one-to-one at the database layer" do
    indexes = described_class.connection.indexes(:video_hub_videos)
    topic_index = indexes.find { |candidate| candidate.columns == ["topic_id"] }
    post_index = indexes.find { |candidate| candidate.columns == ["post_id"] }

    expect(topic_index).to be_present
    expect(topic_index.unique).to eq(true)
    expect(post_index).to be_present
    expect(post_index.unique).to eq(true)
  end

  it "allows core user deletion to nullify the author reference without orphaning the video" do
    user_column =
      described_class
        .connection
        .columns(:video_hub_videos)
        .find { |column| column.name == "user_id" }
    user_fk =
      described_class
        .connection
        .foreign_keys(:video_hub_videos)
        .find { |foreign_key| foreign_key.to_table == "users" }

    expect(user_column).to be_present
    expect(user_column.null).to eq(true)
    expect(user_fk).to be_present
    expect(user_fk.options[:on_delete]).to eq(:nullify)
  end

  it "installs database check constraints for the domain and publish mapping invariants" do
    constraint_names = described_class.connection.check_constraints(:video_hub_videos).map(&:name)

    expect(constraint_names).to include(
      "video_hub_videos_provider",
      "video_hub_videos_kind",
      "video_hub_videos_status",
      "video_hub_videos_duration",
      "video_hub_videos_mapping_pair",
      "video_hub_videos_published_mapping",
    )
  end

  it "indexes public feed and author-profile query prefixes" do
    indexes = described_class.connection.indexes(:video_hub_videos)

    expect(indexes.map(&:columns)).to include(
      %w[status published_at id],
      %w[user_id status published_at id],
    )
  end
end
