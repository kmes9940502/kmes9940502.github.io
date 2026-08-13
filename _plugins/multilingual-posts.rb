# frozen_string_literal: true

# Groups translated posts, selects one representative for aggregate pages, and
# supplies simple translation metadata to Liquid templates.
module MultilingualPosts
  SWITCHER_INCLUDE = '{% include language-switcher.html %}'
  TAB_LABELS = {
    'en' => 'Languages',
    'zh-TW' => '語言'
  }.freeze

  module_function

  def configure(site)
    config = site.config['multilingual']
    fatal!('`multilingual` must be configured in _config.yml.') unless config.is_a?(Hash)

    languages = config['languages']
    fatal!('`multilingual.languages` must contain at least one language.') unless languages.is_a?(Array) && !languages.empty?
    fatal!('Every entry in `multilingual.languages` must be a mapping.') unless languages.all? { |language| language.is_a?(Hash) }

    language_codes = languages.map { |language| language['code'].to_s.strip }
    if language_codes.any?(&:empty?) || language_codes.uniq.length != language_codes.length
      fatal!('Every configured language must have a unique, non-empty `code`.')
    end

    if languages.any? { |language| language['label'].to_s.strip.empty? }
      fatal!('Every configured language must have a non-empty `label`.')
    end

    default_lang = config['default_lang'].to_s.strip
    fatal!("Unknown multilingual.default_lang: #{default_lang}") unless language_codes.include?(default_lang)

    add_tab_labels(site, language_codes)
    groups = validate_and_group(site.posts.docs, language_codes)
    language_order = language_codes.each_with_index.to_h

    groups.each_value do |posts|
      configure_group(posts, default_lang, language_order)
    end
  end

  def validate_and_group(posts, language_codes)
    errors = []
    groups = Hash.new { |hash, key| hash[key] = [] }

    posts.each do |post|
      path = post.relative_path || post.path
      lang = post.data['content_lang'].to_s.strip
      translation_key = post.data['translation_key'].to_s.strip

      errors << "#{path}: remove post-level `lang`; use `content_lang` instead" if post.data.key?('lang')
      errors << "#{path}: missing `content_lang`" if lang.empty?
      errors << "#{path}: unknown `content_lang` #{lang.inspect}" unless lang.empty? || language_codes.include?(lang)
      errors << "#{path}: missing `translation_key`" if translation_key.empty?

      groups[translation_key] << post unless lang.empty? || translation_key.empty? || !language_codes.include?(lang)
    end

    groups.each do |translation_key, group|
      group.group_by { |post| post.data['content_lang'] }.each do |lang, duplicates|
        next if duplicates.length == 1

        paths = duplicates.map { |post| post.relative_path || post.path }.join(', ')
        errors << "translation_key #{translation_key.inspect} has duplicate language #{lang.inspect}: #{paths}"
      end
    end

    fatal!(errors.join("\n")) unless errors.empty?
    groups
  end

  def configure_group(posts, default_lang, language_order)
    ordered = posts.sort_by do |post|
      [language_order.fetch(post.data['content_lang']), post.date, post.relative_path.to_s]
    end

    visible = ordered.reject { |post| post.data['hidden'] == true }
    candidates = visible.empty? ? ordered : visible
    representative = candidates.find { |post| post.data['content_lang'] == default_lang } || candidates.first
    group_pinned = visible.any? { |post| post.data['pin'] == true }

    translations = ordered.map do |post|
      {
        'lang' => post.data['content_lang'],
        'title' => post.data['title'],
        'url' => post.url
      }
    end

    ordered.each do |post|
      post.data['translations'] = translations
      post.data['translation_representative_url'] = representative.url

      if posts.length > 1
        if post.equal?(representative)
          post.data['pin'] = group_pinned
        else
          post.data['hidden'] = true
          post.data['pin'] = false
        end
      elsif post.data['hidden'] == true
        # Chirpy renders pinned posts even when hidden, so avoid contradictory
        # metadata for intentionally hidden single-language posts.
        post.data['pin'] = false
      end
    end
  end

  def add_tab_labels(site, language_codes)
    locales = site.data['locales'] || {}

    language_codes.each do |code|
      next unless locales[code].is_a?(Hash)

      locales[code]['tabs'] ||= {}
      locales[code]['tabs']['languages'] ||= TAB_LABELS.fetch(code, 'Languages')
    end
  end

  def fatal!(message)
    raise Jekyll::Errors::FatalException, "Multilingual posts: #{message}"
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  MultilingualPosts.configure(site)
end

# Keep page.layout as `post` so Chirpy continues loading all post-specific CSS
# and JavaScript. The original content is restored immediately after rendering,
# preventing the switcher from leaking into home-page summaries.
Jekyll::Hooks.register :posts, :pre_render do |post, _payload|
  next unless post.data['translations']

  post.instance_variable_set(:@multilingual_original_content, post.content)
  content_lang = post.data['content_lang']
  post.content = "#{MultilingualPosts::SWITCHER_INCLUDE}\n\n<div lang=\"#{content_lang}\" markdown=\"1\">\n\n#{post.content}\n\n</div>"
end

Jekyll::Hooks.register :posts, :post_render do |post|
  original_content = post.instance_variable_get(:@multilingual_original_content)
  next unless original_content

  post.content = original_content
  post.remove_instance_variable(:@multilingual_original_content)
end
