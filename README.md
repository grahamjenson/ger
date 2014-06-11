GEneric Reccomendations (GER) engine is a simple collaborative filtering reccommendations engine.
It does not contain business rules, or complex logic, just a really fast core that can be understood and built upon.

Tags
Calculator
Microservice
Reccommendations
Generic
Basic
Simple
Hypermedia API


1) No Business Rules
2) No reccommending to action thing that has not been actioned before.
3) easily allowing anonymising people actions and things for cloud deployment

It is built to be configurable to your problem. 
It is also built to be massivly scalable so that
It takes inspration from racoon but tries to be more generic.

It uses a k-nearest-neibough algorithm (k-NN) and weighted Jaccard Distance.

It allows configuration and comes with a learning algorithm so given a test and validation set it will try find the best configuration for you.

#The Math

The three primitives are
People p,q \in p
Actions a,b \in A
Things  t,u \in T

An Event is where a person does an action to a thing represented by the tuple

\open p,a,t \close

E is the set of all events that have happened 

Each Action has a weight, which is an integer represented where given an action a, the weight of action a is 

w_a \in Z

We define two subsets, the set of all events a person has actioned and the of all events for a person

E_p is the set of all events for a person, such that

E_p = { \open p', a, t \close \mid p = p' for all \open p', a, t \close \in E}

E_p^a \sub E is the set of events of a person given an action such that

E_p^a = { \open p, a', t \close \mid a = a' for all \open p, a', t \close \in E_p}


The delta between people given an action a is defined such that

p \delta_a q = |E_p^a \cap E_q^a| / |E_p^a \cup E_q^a|

This is the jaccard distance between the sets of events given an action and person

The delta between people is defined

p \delta q = \sum_{a \in A} w_a \dot p \delta_a q

