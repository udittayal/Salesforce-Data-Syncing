public class DataSyncingTriggerHandler {
    
    public static void publishEvent(List<SObject> sObjectList, Map<Id,SObject> oldMap){
        
        String sObjectName = sObjectList[0].Id.getSObjectType().getDescribe().getName();
        List<Data_Sync_Event__e> dataSyncEventList = new List<Data_Sync_Event__e>();
        Set<String> setofAPINames = new Set<String>();
        
        switch on Trigger.OperationType{
            
            WHEN AFTER_UPDATE{
                Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
                for(String key : fieldsMap.keySet()){
                    Schema.DescribeFieldResult fieldResult = fieldsMap.get(key).getDescribe();
                    if(fieldResult.isUpdateable()){
                        setofAPINames.add(fieldResult.getName());
                    }
                }
            }
        }
        
        for(SObject recordObj : sObjectList){
        
        switch on Trigger.OperationType{
            
            WHEN AFTER_INSERT{
                Data_Sync_Event__e dataSyncEventObj = new Data_Sync_Event__e();
                dataSyncEventObj.Record_Id__c = recordObj.Id;
                dataSyncEventObj.Event_Type__c = 'INSERT';
                dataSyncEventObj.Object_Name__c = sObjectName;
                dataSyncEventList.add(dataSyncEventObj);
            }
            
            WHEN AFTER_UPDATE{
                
                String fieldsChanged = '';
                
                for(String fieldApiName : setofAPINames){
                    if(fieldApiName != 'External_Id__c'){
                        if(recordObj.get(fieldApiName) != oldMap.get(recordObj.Id).get(fieldApiName)){
                            fieldsChanged += fieldApiName + ',';
                        }
                    }
                    
                }
                
                fieldsChanged = fieldsChanged.removeEnd(',');

                if(fieldsChanged != ''){
                    Data_Sync_Event__e dataSyncEventObj = new Data_Sync_Event__e();
                    dataSyncEventObj.Record_Id__c = recordObj.Id;
                    dataSyncEventObj.Event_Type__c = 'UPDATE';
                    dataSyncEventObj.Object_Name__c = sObjectName;
                    dataSyncEventObj.Fields_Changed__c = fieldsChanged;
                    dataSyncEventList.add(dataSyncEventObj);     
                }
            }
            
            WHEN AFTER_DELETE{
                Data_Sync_Event__e dataSyncEventObj = new Data_Sync_Event__e();
                dataSyncEventObj.Record_Id__c = recordObj.Id;
                dataSyncEventObj.Event_Type__c = 'DELETE';
                dataSyncEventObj.Object_Name__c = sObjectName;
                dataSyncEventList.add(dataSyncEventObj);                                
            }
            
            
        }
        }
        
        if(dataSyncEventList.size() > 0){
            System.debug('eventList #####'+Json.serialize(dataSyncEventList));
            EventBus.publish(dataSyncEventList);
        }
        
        
    }

}