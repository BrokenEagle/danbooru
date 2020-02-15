module ForumTopicsHelper
  def forum_topic_category_select(object, field)
    select(object, field, ForumTopic.reverse_category_mapping.to_a)
  end

  def available_min_user_levels
    ForumTopic::MIN_LEVELS.select { |name, level| level <= CurrentUser.level }.to_a
  end

  def new_forum_topic?(topic, read_forum_topics)
    !read_forum_topics.map(&:id).include?(topic.id)
  end

  def bulk_update_request_counts(topic)
    requests = []
    requests << "<span style='color:orange'>Pending:</span> #{topic.pending_bur_count}" if topic.pending_bur_count > 0
    requests << "<span style='color:green'>Approved:</span> #{topic.approved_bur_count}" if topic.approved_bur_count > 0
    requests << "<span style='color:red'>Rejected:</span> #{topic.rejected_bur_count}" if topic.rejected_bur_count > 0
    requests.join(", ").html_safe
  end
end
