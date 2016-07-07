import re
import sys
from imgurpython import ImgurClient
from urllib import urlretrieve

client_id = '5e6b7e85cfe7bf4'
client_secret = '1d684f6e2bcd1593ef30e4f95b1df672a05f21ce'

client = ImgurClient(client_id, client_secret)

imgURL = sys.argv[1]

if 'imgur.com/a/' in imgURL:
    match = re.search(r'(imgur.com/a/)(\w+)', imgURL)
    print match.group(2)
    info = client.get_album(match.group(2))
    imgURL = 'http://i.imgur.com/'+info.cover+'b.jpg'
elif 'imgur.com/gallery' in imgURL:
    match = re.search(r'(imgur.com/gallery/)(\w+)', imgURL)
    print match.group(2)
    try:
        info = client.get_album(match.group(2))
        imgURL = 'http://i.imgur.com/'+info.cover+'b.jpg'
    except:
        imgURL = 'http://i.imgur.com/'+match.group  (2)+'b.jpg'
else:
    match = re.search(r'(imgur.com/)(\w+)', imgURL)
    imgURL = 'http://i.imgur.com/'+match.group(2)+'b.jpg'



outpath = 'out/'+sys.argv[2]+'.jpg'

fileData = urlretrieve(imgURL, outpath)
