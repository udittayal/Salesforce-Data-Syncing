# Salesforce Data Syncing between two Orgs

## I have used the concepts of Platform Events to Bulkify DML Events performed in Base Org

## Approach

1. Once a record is created in Base Org, an External Id field will be updated from record Id and will be passed in the Target Org
2. By passing External Id we can easily update the records in Target Org
3. Once a Trigger is executed, a list of platform events are published and relevant information like Object name, Record Id, Fields Changed is passed.
4. I have used the generic methods such that same logic can be used in multiple objects after doing some pre-requisite activities
5. Platform event subscribers queries the data and prepare composite graph body and dynamically create graphs based on the number of records to be created/updated/deleted
6. With the following apporach, one can setup data syncing within a short span of time.


## Future works and Current Challenges

1. Creation of child record along with lookup value of the parent.
2. API Logger to store the logs
3. Retry logic for the failed records.
