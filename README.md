Good Enough Reccomendations (GER) is a simple recomendations engine that uses collaborative filtering.
GER is built to be a very fast, scalable calculator that can be built upon and wrapped to add specific features that you may need.

The API of GER is 

```coffeescript
event(person: String, action: String)
```

1) No Business Rules
2) No reccommending to action thing that has not been actioned before.
3) easily allowing anonymising people actions and things for cloud deployment

It is built to be configurable to your problem. 
It is also built to be massivly scalable so that
It takes inspration from racoon but tries to be more generic.

It uses a k-nearest-neibough algorithm (k-NN) and weighted Jaccard Distance.

It allows configuration and comes with a learning algorithm so given a test and validation set it will try find the best configuration for you.


