trigger accountTrigger on Account (after insert,after update,after delete,after undelete) {

    DataSyncingTriggerHandler.publishEvent(Trigger.new,Trigger.oldMap);
    
}