module WikiPageVersionsHelper
  def show_diff(wiki_page_version, type)
    other = wiki_page_version.send(type)
    other.present? && ((wiki_page_version.other_names != other.other_names) || wiki_page_version.other_names_changed(type))
  end

  def wiki_page_title_diff(wiki_page_version, type)
    other = wiki_page_version.send(type)
    if other.present? && (wiki_page_version.title != other.title)
      if type == "previous"
        name_diff = diff_name_html(wiki_page_version.title, other.title)
      else
        name_diff = diff_name_html(other.title, wiki_page_version.title)
      end
      %((<b>Rename:</b>&ensp;#{name_diff})).html_safe
    else
      ""
    end
  end

  def wiki_other_names_diff(new_version, old_version)
    new_names = new_version.other_names
    old_names = old_version.other_names

    diff_list_html(new_names, old_names, ul_class: ["wiki-other-names-diff-list list-inline"], li_class: ["wiki-other-name"])
  end
end
