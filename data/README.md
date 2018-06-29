# Facebook Friendbot Factory

## Data

This subdirectory is intended to host the input/ouput data produced & consumed by our friendbot-factory.

By default, there are 3 intended subdirectories:

1. [facebook_unstructured](facebook_unstructured) - default location for our [uncompressed facebook archive](https://www.facebook.com/help/212802592074644?helpref=uf_permalink)
2. [facebook_structured](facebook_structured) - default location for structured results as parsed by the [facebook-archive-parser tool](https://github.com/ownaginatious/fbchat-archive-parser)
3. [facebook_parsed](facebook_parsed) - available (not currently leveraged) subdirectory for results parsed by [fb\_messages\_parser.py](https://github.com/martelogan/fb-friendbot-factory/blob/master/app/python/fb_messages_parser.py)

Each data stage is detailed further in its own subdirectory.

License
-------

This code is under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

If you use or modify _fb-friendbot-factory_, please credit the original author as

* Logan Martel - https://github.com/martelogan
