
# TenTags.io

* [About](#about)
* [Installation](#installation)
* [Technical](#technical)

## About

Tentags is a content aggregration site à la Reddit/Voat/HN, but works a little differently under the hood:

### Tags
Unsurprisingly, tags are at the core of TenTags. Each time you post to the site, you can add up to 10 tags to your post; the tags on a post decide which communities see your post. But since we don't trust you (sorry!), we let the community decide if your tags are legit, and even add their own; Instead of voting on posts users can vote on each tag, allowing the same post to have a different score per filter.
### Filters
Filters are 'communities' (subs) of people that want to see the same content based on the tags on each post. They are defined by tags that people want to and don't want to see, e.g. 'sfwpics' could be all posts tagged 'pics' except those tagged 'nsfw'.

#### Post Once
As the tag scores govern which communities see a post, there's no need to crosspost, you can just add more tags to the post, e.g. you could tag a post 'tech' and 'android' and it would appear in the 'tech' filter, and the 'android' filter, but not the 'apple' filter.

#### See Once
Fed up of stale content? You can set posts to auto hide after you've voted on them, clicked on them, or even just seen them, so that you always see fresh content, even when moving between devices.

#### Post Anything
What if you could share a link, AND write something about it? (Crazy right?) We've got you covered. Share links, images, videos, gifs, and albums. Comment on them. Go Crazy. We'll even let you fix that typo in your title if you're quick
Subscribe to Anything
No more 'remind me!' comments, simply click to subscribe to individual comment replies, all post replies, or to users to get all updates directly to your inbox.
All the comments in one place
As posts arent linked to filters, you can end up having multiple communities commenting on the same content. For easy browsing, you can filter comments by the community they came from.

#### No reposts
No one likes reposts, but there's always a first time for everyone. That's why we've added a repost reporting feature. Users can tag a post with its source post, and only people that haven't seen the original will see the new post.
One account, multiple users
Create additional users and easily switch between them without relogging, e.g. for seperate work/home accounts
Passwordless
Fed up of data leaks? We can't do security so we don't try. Passwordless logins make it someone elses problem; we don't even store your email address!

#### NSFW!!!!
Everyone's workplace is different, and 'NSFW' can range from 'phalic object on screen' to 'keep it legal.' For that reason, we have a more fine grained nsfw setting, to avoid any awkward conversations with the boss. While we're at it, there's a seperate NSFL setting, so you won't get surprised by maggots instead of mammaries, or nails instead of nailing.

## Installation
Requires docker-compose.

```
docker-compose -f dc.yml build

sh startdev.sh
```

## Technical

Tentags.io uses [Lapis](http://leafo.net/lapis/), a web framework built on [Openresty](https://openresty.org/en/), with Redis as a backend database and queue, Backblaze B2 for file storage, and ffmpeg for video processing.

Each post has a set of tags that can be voted up and down by users, and each filter contains a list of post that contain tags required by the filter, and not those unwanted by the filter.
In this way every post has its own seperate score per-filter.

### Image processing
##### Links
The image processing service attempts to intelligently get the thumbnail from common websites (Imgur API, gfycat thumbnail URLs, etc), and then falls back to scraping the largest image it can find on the page. The image is then processed to the correct format and size using ImageMagick.

#### Images
Directly uploaded images are converted to JPG and optimised, then stored as a thumbnail, medium size, and original

* Gifs are converted to MP4
* Any other video formats are converted to mp4, scaled and optimized.
* MP4's more than 15 seconds are converted to a 'preview clip' with 10 1 second segments of the video.
* MP4's (or their preview) are converted to fallback gifs.



### Caching
Tentags.io uses Nginx to cache all logged out requests and images from Backblaze.

Users/Posts/Filters are cached in Openresty [shdict](https://github.com/openresty/lua-nginx-module#ngxshareddict) shared memory zones

Valid writes are written directly to the cache and queued to shdict for deferred processing by the background workers, and cache invalidation on other servers.

### Other
Tentags.io Uses the excellent [Scaling Bloom Filter](https://github.com/erikdubbelboer/redis-lua-scaling-bloom-filter) library by erikdubbelboer to store per-user seen posts, post/comment/tag votes efficiently.
Passwordless logins use a salted hash of the email to identify users without storing their email addresses.
