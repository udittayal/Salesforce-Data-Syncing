public class DataSyncEventHandler {
    
    @future(Callout=True)
    public static void syncRecords(String dataSyncEventPayLoad){
        
        //Variable Declaration                
        Map<String,Set<String>> mapofObjectToRecordIds = new Map<String,Set<String>>();
        Map<String, Schema.SObjectType> sObjectDescribeMap = Schema.getGlobalDescribe();
        Map<Id,SObject> mapofObjectToAllRecords = new Map<Id,SObject>();
        Map<String,Set<String>> mapofObjectToApiName = new Map<String,Set<String>>();
        List<CompositeRequest> listofCompositeRequest = new List<CompositeRequest>();
        
        List<Data_Sync_Event__e> dataSyncEventList = (List<Data_Sync_Event__e>)Json.deserialize(dataSyncEventPayLoad,List<Data_Sync_Event__e>.class);
        
        //Fetching the list of Record Ids for every Object
        for(Data_Sync_Event__e dataSyncEventObj : dataSyncEventList){
            if(!mapofObjectToRecordIds.containsKey(dataSyncEventObj.Object_Name__c)){
                mapofObjectToRecordIds.put(dataSyncEventObj.Object_Name__c, new Set<String>{});
            }
            mapofObjectToRecordIds.get(dataSyncEventObj.Object_Name__c).add(dataSyncEventObj.Record_Id__c);
        }        
                
        //Query on the objects and fetching API Names for Preparing Composite Request Body
        for(String sObjectName : mapofObjectToRecordIds.keySet()){
            Set<String> setofRecordIds = mapofObjectToRecordIds.get(sObjectName);
            String query = 'SELECT ';
            Map<String,Schema.SObjectField> mapofSObjectFields = sObjectDescribeMap.get(sObjectName).getDescribe().fields.getMap();
            for(String fieldname : mapofSObjectFields.keySet()){
                if(mapofSObjectFields.get(fieldname).getDescribe().isUpdateable()){
                    if(!mapofObjectToApiName.containsKey(sObjectName)){
                        mapofObjectToApiName.put(sObjectName, new Set<String>{});
                    }
                    mapofObjectToApiName.get(sObjectName).add(fieldname);
                    String apiName = mapofSObjectFields.get(fieldname).getDescribe().getName();
                    query += apiName + ',';
                }
            }
            query = query.removeEnd(',');
            query = query + ' FROM ' + sObjectName + ' WHERE Id IN :setofRecordIds';
            Map<Id,SObject> mapofSObjectRecord = new Map<Id,SObject>(Database.query(query));
            mapofObjectToAllRecords.putAll(mapofSObjectRecord);
        }
        
        //Generating composite API Request Body
        for(Data_Sync_Event__e dataSyncEventObj : dataSyncEventList){
            CompositeRequest compositeReqObj = new CompositeRequest(); 
            if(dataSyncEventObj.Event_Type__c == 'INSERT'){
                compositeReqObj.method = 'POST';
                compositeReqObj.url = '/services/data/v63.0/sobjects/' +dataSyncEventObj.Object_Name__c;
                Map<String,Object> mapofRecord = new Map<String,Object>();
                SObject objRecord = mapofObjectToAllRecords.get(dataSyncEventObj.Record_Id__c);
                for(String fieldApiName : mapofObjectToApiName.get(dataSyncEventObj.Object_Name__c)){
                    if(objRecord.get(fieldApiName) != null && fieldApiName != 'OwnerId'){
                    	mapofRecord.put(fieldApiName,objRecord.get(fieldApiName));
                    }
                }
                compositeReqObj.body = mapofRecord;
            }else if(dataSyncEventObj.Event_Type__c == 'UPDATE'){
                compositeReqObj.method = 'PATCH';
                compositeReqObj.url = '/services/data/v63.0/sobjects/' +dataSyncEventObj.Object_Name__c + '/External_Id__c/' + dataSyncEventObj.Record_Id__c;
                Map<String,Object> mapofRecord = new Map<String,Object>();
                SObject sobjRecord = mapofObjectToAllRecords.get(dataSyncEventObj.Record_Id__c);
                for(String fieldName : dataSyncEventObj.Fields_Changed__c.split(',')){
                    mapofRecord.put(fieldName,sobjRecord.get(fieldName));
                }
                compositeReqObj.body = mapofRecord;
            }else if(dataSyncEventObj.Event_Type__c == 'DELETE'){
                compositeReqObj.method = 'DELETE';
                compositeReqObj.url = '/services/data/v63.0/sobjects/' +dataSyncEventObj.Object_Name__c + '/External_Id__c/' + dataSyncEventObj.Record_Id__c;
            }
            listofCompositeRequest.add(compositeReqObj);  //Add composite Request
        }
        
        
        //
        //Note - 75 is the maximum number of Graphs in a Composite Graph Call
        integer requestSize = listofCompositeRequest.size();
        integer chunkSize = requestSize < 75 ? 1 : Integer.valueOf(requestSize/75);
        integer chunkCounter = 0;
        integer graphCounter = 1;
        
        List<Graphs> listofGraph = new List<Graphs>();
        List<CompositeRequest> requestList = new List<CompositeRequest>();

        //Dynamically Dividing graphs
        //Ex - Record count is 150
        //75 graphs with 2 SubRequests will be passed
        for(CompositeRequest compositeRequestObj : listofCompositeRequest){
            requestList.add(compositeRequestObj);
            if(requestList.size() == chunkSize){
                List<CompositeRequest> clonedRequestList = requestList.clone();
                Graphs graphObj = new Graphs();
                graphObj.compositeRequest = clonedRequestList;
                graphObj.graphId = 'graph '+graphCounter;
                listofGraph.add(graphObj);
                graphCounter += 1;
                requestList.clear();
            }
        }
        
        CompositeGraph compositeGraphObj = new CompositeGraph();
        compositeGraphObj.graphs = listofGraph;
        
        system.debug('requestBody ######'+Json.serialize(compositeGraphObj));
        
        
        //Calling Composite API
        HttpRequest requestObj = new HttpRequest();
        requestObj.setEndpoint('callout:Target_Org/services/data/v63.0/composite/graph');
        requestObj.setMethod('POST');
        requestObj.setBody(Json.serialize(compositeGraphObj));
        requestObj.setHeader('Accept','application/json');
        requestObj.setHeader('Content-Type','application/json');
        HttpResponse responseObj = new Http().send(requestObj);
        system.debug('response ####'+responseObj.getBody());
    }
    
    
    public class CompositeGraph{
        public List<Graphs> graphs;
    }
    
    public class Graphs{
        public String graphId;
        public List<CompositeRequest> compositeRequest;
    }
    
    public class CompositeRequest{
        public Object body;
        public String method;
        public String url;
        public String referenceId = 'ref1';
    }
}