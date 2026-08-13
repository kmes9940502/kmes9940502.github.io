# Chirpy Starter

[![Gem Version](https://img.shields.io/gem/v/jekyll-theme-chirpy)][gem]&nbsp;
[![GitHub license](https://img.shields.io/github/license/cotes2020/chirpy-starter.svg?color=blue)][mit]

A minimal, ready-to-use template for creating a blog with the [**Chirpy**][chirpy] Jekyll theme. Get up and running in minutes with all critical files pre-configured.

## Why This Starter Exists

When installing Chirpy through [RubyGems.org][gem], Jekyll can only read a subset of theme files (`_data`, `_layouts`, `_includes`, `_sass`, `assets`) and limited `_config.yml` options from the gem. As a result, users cannot enjoy the full out-of-the-box experience that Chirpy offers.

To unlock all features, the following files must be present in your Jekyll site:

```shell
.
├── _config.yml
├── _plugins
├── _tabs
└── index.html
```

This starter bundles those files from the latest **Chirpy** release along with a [CD][CD] workflow, so you can start writing immediately.

## Usage

Check out the [theme's docs](https://github.com/cotes2020/jekyll-theme-chirpy/wiki).

## Contributing

This repository is automatically updated with new releases from the theme repository. If you encounter any issues or want to contribute to its improvement, please visit the [theme repository][chirpy] to provide feedback.

## License

This work is published under [MIT][mit] License.

## Multilingual posts

Every post must declare a supported language and a stable translation key, even
if only one language is currently available:

```yaml
content_lang: zh-TW
translation_key: stable-topic-name
```

Supported content language codes are `en` and `zh-TW`. To add a translation,
create a new post with the translated title and content, change
`content_lang`, and reuse the same `translation_key`. Do not add language names
to `tags`, set `hidden`, or manually maintain links between versions. The
multilingual build plugin handles article pairing, aggregate-page visibility,
the language switcher, and `hreflang` metadata automatically.

Do not set a post-level `lang`: Chirpy treats it as the language of the entire
site interface. The global interface remains English, while `content_lang`
describes only the article body.

Recommended filenames for new posts are `YYYY-MM-DD-slug-en.md` and
`YYYY-MM-DD-slug-zh-tw.md`. Existing files keep their current names so their
URLs remain stable.

[gem]: https://rubygems.org/gems/jekyll-theme-chirpy
[chirpy]: https://github.com/cotes2020/jekyll-theme-chirpy/
[CD]: https://en.wikipedia.org/wiki/Continuous_deployment
[mit]: https://github.com/cotes2020/chirpy-starter/blob/master/LICENSE
