--!strict
--[[
    Stores configuration values for PlayerStore
]]

type DataVisibilityTree = boolean
    | {[string]: DataVisibilityTree}
    | {DataVisibilityTree}
type Config_DataVisibility = {
    VisibleToOwnClient: DataVisibilityTree,
    VisibleToAllClients: DataVisibilityTree,
}
type ConfigPartial_DataVisibility = {
    VisibleToOwnClient: DataVisibilityTree?,
    VisibleToAllClients: DataVisibilityTree?,
}

type Config_MigrateLegacyData = (
    storedLegacyData: any
) -> {[string]: any}

type Config_WaitForExitSaveBeforeLoading = {
    Enabled: boolean,
    RetryInterval: number,
    MaxRetries: number,
    TimeoutForRecentServers: number,
    TimeoutForSuspectedCrashedServers: number,
}
type ConfigPartial_WaitForExitSaveBeforeLoading = {
    Enabled: boolean?,
    RetryInterval: number?,
    MaxRetries: number?,
    TimeoutForRecentServers: number?,
    TimeoutForSuspectedCrashedServers: number?,
}

type Config_AutoSaving = {
    Enabled: boolean,
    Interval: number,
}
type ConfigPartial_AutoSaving = {
    Enabled: boolean?,
    Interval: number?,
}

type Config_SaveRetries = {
    Enabled: boolean,
    Interval: number,
    Max: number,
}
type ConfigPartial_SaveRetries = {
    Enabled: boolean?,
    Interval: number?,
    Max: number?,
}

type Config_Logging = {
    Enabled: boolean,
    OnLoad: boolean,
    OnMigration: boolean,
    OnLoadStatusUpdate: boolean,
    OnSaveStatusUpdate: boolean,
    OnTradeStatusUpdate: boolean,
    OnAutoSave: boolean,
    OnExitSave: boolean,
    MessageFormat: string,
}
type ConfigPartial_Logging = {
    Enabled: boolean?,
    OnLoad: boolean?,
    OnMigration: boolean?,
    OnLoadStatusUpdate: boolean?,
    OnSaveStatusUpdate: boolean?,
    OnTradeStatusUpdate: boolean?,
    OnAutoSave: boolean?,
    OnExitSave: boolean?,
    MessageFormat: string?,
}

type Config_BindToClose = {
    EnableWhileInStudio: boolean,
    TimeoutWhileInStudio: number,
    SaveRetryEnabled: boolean,
    SaveRetryInterval: number,
}
type ConfigPartial_BindToClose = {
    EnableWhileInStudio: boolean?,
    TimeoutWhileInStudio: number?,
    SaveRetryEnabled: boolean?,
    SaveRetryInterval: number?,
}

export type Config = {
    DataVisibility: Config_DataVisibility,
    MigrateLegacyData: Config_MigrateLegacyData?,
    WaitForExitSaveBeforeLoading: Config_WaitForExitSaveBeforeLoading,
    AutoSaving: Config_AutoSaving,
    SaveRetries: Config_SaveRetries,
    Logging: Config_Logging,
    BindToClose: Config_BindToClose,
}
export type ConfigPartial = {
    DataVisibility: ConfigPartial_DataVisibility?,
    MigrateLegacyData: Config_MigrateLegacyData?,
    WaitForExitSaveBeforeLoading: ConfigPartial_WaitForExitSaveBeforeLoading?,
    AutoSaving: ConfigPartial_AutoSaving?,
    SaveRetries: ConfigPartial_SaveRetries?,
    Logging: ConfigPartial_Logging?,
    BindToClose: ConfigPartial_BindToClose?,
}

local defaultConfig: Config = {
    -- (Opt-In) Data Replication Mechanism
    DataVisibility = {
        VisibleToOwnClient = false,
        VisibleToAllClients = false,
    },

    -- (Opt-in) Mechanism to migrate legacy data before PlayerSave was used in
    -- a given project
    MigrateLegacyData = nil,

    -- (Opt-out) Universe teleport + server crash tolerance mechanism
    WaitForExitSaveBeforeLoading = {
        Enabled = true,
        RetryInterval = 8,
        MaxRetries = 6,
        TimeoutForRecentServers = 20,
        TimeoutForSuspectedCrashedServers = 10,
    },

    -- (Opt-out) Autosave mechanism
    AutoSaving = {
        Enabled = true,
        Interval = 60,
    },
    
    -- (Opt-out) Save retry mechanism
    SaveRetries = {
        Enabled = true,
        Interval = 10,
        Max = 6,
    },

    -- (Opt-in) non-error logging output
    Logging = {
        Enabled = true,
        OnLoad = true,
        OnMigration = true,
        OnLoadStatusUpdate = true,
        OnSaveStatusUpdate = true,
        OnTradeStatusUpdate = true,
        OnAutoSave = true,
        OnExitSave = true,
        MessageFormat = "[PlayerSave Logging]: %s",
    },

    -- (Opt-out) BindToClose exit save mechanism
    BindToClose = {
        EnableWhileInStudio = true,
        TimeoutWhileInStudio = 30,
        SaveRetryEnabled = true,
        SaveRetryInterval = 6,
    },
}

return defaultConfig