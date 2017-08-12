# Facebook Friendbot Factory

## Automated Pipeline to Train & Deploy _Fb-Friendified_ Chatbots

This project provides a convenient environment and automation pipeline
to 
1. Construct trainable conversation data from Facebook Messenger chat history
2. Train chatbot models of  individual friends based on conversation data
3. Wrap these models for simple deployment to fit third-party chatbot API

## Current Project Status

1. **ready** - config demonstrated via DeepQA-trainable execution
2. **ready** - successful batch training demonstrated via DeepQA module
3. **todo** - need to script deployment and prepare example wrapper

## Installation & Execution

Assuming that all external dependencies are ready and respective paths 
appropriately specified under the **[config](config)** subdirectory, the training
and deployment execution scripts can be run immediately from the project root.

Of course, the environment setup has some fairly strict requirements: 

1. Ensure that your local environment is equipped with a Bash version >=3, in addition to <br>
seperate distributions of Python 2.7+ and Python 3+ (ideally managed by [conda](https://docs.continuum.io/anaconda/))
<br>

2. Install the [fb-chat-archive-parser](https://github.com/ownaginatious/fbchat-archive-parser) via pip under the Python 2.7 environment by running:
```bash
   pip install fbchat-archive-parser
```
<br>

3. Install some training library to which the friendbot factory will relay conversation data for consumption 
<br> (the default is [DeepQA](https://github.com/Conchylicultor/DeepQA))
<br>

4. Ensure that an uncompressed 
[facebook archive](https://www.facebook.com/help/212802592074644?helpref=uf_permalink)
is made available <br> (conventionally under _[data/facebook_unstructured](data/facebook_unstructured)_)
<br>

5. Specify desired setup at _[config/training/training.config](config/training)_ & _[config/deployment/deployment.config](config/deployment)_
<br>

6. Run `./train.sh` or `./deploy.sh` from project root per relevant task


## Citation

If you use or modify the fb-friendbot-factory project, please credit the original author as

* Logan Martel - https://github.com/martelogan
