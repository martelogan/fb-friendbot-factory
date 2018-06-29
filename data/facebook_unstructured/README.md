# Facebook Friendbot Factory

## Facebook Unstructured

This subdirectory is intended to host the raw, uncompressed - and unstructured - facebook archive data
(as retrieved directly from [facebook's archive download](https://www.facebook.com/help/212802592074644?helpref=uf_permalink))

By default, the folder will be named _facebook-\<USERNAME\>_. We are interested in the message content stored under
_facebook-\<USERNAME\>/html/messages.htm_ . This is the file that **[fbcap](https://github.com/ownaginatious/fbchat-archive-parser/)** will transform to a structured format.

License
-------

This code is under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

If you use or modify _fb-friendbot-factory_, please credit the original author as

* Logan Martel - https://github.com/martelogan
