trigger DataSyncEventTrigger on Data_Sync_Event__e (after insert) {

    DataSyncEventHandler.syncRecords(Json.serialize(trigger.new));

}