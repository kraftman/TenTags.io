import re
import sys
import os
from imgurpython import ImgurClient
from urllib import urlretrieve

client_id = os.environ['IMGUR_ID']
client_secret = os.environ['IMGUR_SECRET']

client = ImgurClient(client_id, client_secret)

imgURL = sys.argv[1]
imgID = ''

if 'imgur.com/a/' in imgURL:
    match = re.search(r'(imgur.com/a/)(\w+)', imgURL)

    info = client.get_album(match.group(2))
    imgURL = 'http://i.imgur.com/'+info.cover+'l.jpg'
    imgID = info.cover
elif 'imgur.com/gallery' in imgURL:
    match = re.search(r'(imgur.com/gallery/)(\w+)', imgURL)

    try:
        info = client.get_album(match.group(2))
        imgURL = 'http://i.imgur.com/'+info.cover+'l.jpg'
        imgID = info.cover
    except:
        imgURL = 'http://i.imgur.com/'+match.group(2)+'l.jpg'
        imgID = match.group(2)
elif 'imgur.com/r/' in imgURL:
    match = re.search(r'(imgur.com/r/\w+/)(\w+)', imgURL)

    try:
        info = client.get_album(match.group(2))
        imgURL = 'http://i.imgur.com/'+info.cover+'l.jpg'
        imgID = info.cover
    except:
        imgURL = 'http://i.imgur.com/'+match.group(2)+'l.jpg'
        imgID = match.group(2)
else:
    match = re.search(r'(imgur.com/)(\w+)', imgURL)
    imgURL = 'http://i.imgur.com/'+match.group(2)+'l.jpg'
    imgID = match.group(2)



outpath = 'out/'+sys.argv[2]+'.jpg'

fileData = urlretrieve(imgURL, outpath)
print('http://i.imgur.com/'+imgID+'.jpg')
