# Overview
# 
The table Campaign_State_Machine__mdt describes, in data, the implementation of 
a DAG (directed acyclical graph / state machine). 

This DAG represents states and transitions within the Cartology sales and
operating workflow. The column Accessible_Stage__c describes the current
state of a workflow, and the column Next_Possible_Stage__c describes a
legal state for the workflow.

So given:

Accessible_Stage__c   | Next_Possible_Stage__c
--------------------------------------------
                      | Planning
Planning              | OpportunityIdentified
OpportunityIdentified | OpportunityDiscussed
Planning              | OpportunityLost

It's legal to enter the workflow in stage Planning, and from Planning
it's legal to move to the OpportunityIdentified or ResponseShared states.

Your task is to implement the logic of the InterviewTest.validate
method, so that given any two input states, it returns whether a 
target state (Next_Possible_Stage__c) is reachable from a source state
(Accessible_Stage__c).

So in the above table:

**Planning**              is reachable from the start (empty) state
**OpportunityIdentified** is reachable from Planning
**OpportunityDiscussed**  is reachable from OpportunityIdentified
**OpportunityDiscussed**  is reachable from Planning 
**OpportunityLost**       is reachable from Planning

OpportunityLost is not reachable from any state apart from Planning.

Your work should focus on the implementation of the validate method
of the InterviewTest class. The method willn accept two stages (states)
and will return a boolean if `toStageName` is reachable from `fromStageName`.

Not every valid path between two stages has it's own row in the database. 
eg.

`Planning` --> `OpportunityIdentified` --> `OpportunityDiscussed`

means that InterviewTest.valiedate(Planning, OpportunityDiscussed)

should return true.

Given the state machine records in the customMetadata folder, 
your implementation should demonstrate a good working knowledge of the 
data structures involved, and algorithms used to navigate these. A clear 
design ism more important than a perfect implementation and we will ask 
for your own ideas on how your solution can be improved after your
submission has been received. Please feel free to reach out with any questions.

