require_relative 'blog'

module Contentful
  module Exporter
    module Wordpress
      class Post < Blog
        attr_reader :xml, :settings

        def initialize(xml, settings)
          @xml = xml
          @settings = settings
        end

        def post_extractor
          output_logger.info 'Extracting posts...'
          create_directory("#{settings.entries_dir}/post")
          extract_posts
        end

        def post_id(post)
          "post_#{post.xpath('wp:post_id').text}"
        end

        private

        def extract_posts
          posts.each_with_object([]) do |post_xml, posts|
            normalized_post = extract_data(post_xml)
            write_json_to_file("#{settings.entries_dir}/post/#{post_id(post_xml)}.json", normalized_post)
            posts << normalized_post
          end
        end

        def posts
          xml.xpath('//item').to_a
        end

        def extract_data(xml_post)
          post_entry = basic_post_data(xml_post)
          assign_content_elements_to_post(xml_post, post_entry)
          post_entry
        end

        def attachment(xml_post)
          PostAttachment.new(xml_post, settings).attachment_extractor
        end

        def author(xml_post)
          PostAuthor.new(xml, xml_post, settings).author_extractor
        end

        def tags(xml_post)
          PostCategoryDomain.new(xml, xml_post, settings).extract_tags
        end

        def categories(xml_post)
          PostCategoryDomain.new(xml, xml_post, settings).extract_categories
        end

        def basic_post_data(xml_post)
          {
            id: post_id(xml_post),
            title: title(xml_post),
            wordpress_url: url(xml_post),
            content: content(xml_post),
            created_at: created_at(xml_post),
            category: category(xml_post)
          }
        end

        def assign_content_elements_to_post(xml_post, post_entry)
          attachment = attachment(xml_post)
          tags = link_entry(tags(xml_post))
          categories = link_entry(categories(xml_post))
          post_entry.merge!(author: link_entry(author(xml_post)))
          post_entry.merge!(attachment: link_asset(attachment)) unless attachment.nil?
          post_entry.merge!(tags: tags) unless tags.empty?
          post_entry.merge!(categories: categories) unless categories.empty?
        end

        def title(xml_post)
          xml_post.xpath('title').text
        end

        def url(xml_post)
          xml_post.xpath('link').text
        end

        def content(xml_post)
          xml_post.xpath('content:encoded').text
        end

        def created_at(xml_post)
          ['wp:post_date', 'wp:post_date_gmt'].each do |date_field|
            date_string = xml_post.xpath(date_field).text
            return Date.strptime(date_string) unless date_string.empty?
          end
          output_logger.warn "Post <#{post_id(xml_post)}> didn't have Creation Date - defaulting to #{Date.today}"
          Date.today
        end

        def category(xml_post)
          xml_post.search('category[domain="category"]').text.try(:sub, '<![CDATA[', '').try(:sub, ']]', '')
        end
      end
    end
  end
end
