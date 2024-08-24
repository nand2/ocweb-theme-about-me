<script setup>
import { computed, ref } from 'vue'
import { useQueryClient, useMutation } from '@tanstack/vue-query'

import { useStaticFrontendPluginClient, invalidateStaticFrontendFileContentQuery } from 'ocweb/src/plugins/staticFrontend/pluginStaticFrontendQueries.js';

const props = defineProps({
  websiteVersion: {
    type: Object,
    required: true
  },
  websiteVersionIndex: {
    type: Number,
    required: true,
  },
  contractAddress: {
    type: String,
    required: true,
  },
  chainId: {
    type: Number,
    required: true,
  },
  websiteClient: {
    type: Object,
    required: true,
  },
  plugins: {
    type: Array,
    required: true,
  },
})

const queryClient = useQueryClient()

// Get the staticFrontendPlugin
const staticFrontendPlugin = computed(() => {
  return props.plugins.find(plugin => plugin.infos.name == 'staticFrontend')
})


// Get the staticFrontendPluginClient
const { data: staticFrontendPluginClient, isLoading: staticFrontendPluginClientLoading, isFetching: staticFrontendPluginClientFetching, isError: staticFrontendPluginClientIsError, error: staticFrontendPluginClientError, isSuccess: staticFrontendPluginClientLoaded } = useStaticFrontendPluginClient(props.contractAddress, staticFrontendPlugin.value.plugin)


// Form fields
const name = ref("")


// Prepare the addition of files
const filesAdditionTransactions = ref([])
const skippedFilesAdditions = ref([])
const { isPending: prepareAddFilesIsPending, isError: prepareAddFilesIsError, error: prepareAddFilesError, isSuccess: prepareAddFilesIsSuccess, mutate: prepareAddFilesMutate, reset: prepareAddFilesReset } = useMutation({
  mutationFn: async () => {
    // Reset any previous upload
    addFileTransactionBeingExecutedIndex.value = -1
    addFileTransactionResults.value = []

    // Convert the text to a UInt8Array
    const textData = JSON.stringify({name: name.value});

    // Prepare the files for upload
    const fileInfos = [{
      // If existing file : Reuse same filePath, we rename after
      filePath: 'themes/about-me/config.json',
      size: textData.length,
      contentType: "application/json",
      data: textData,
    }]
    console.log(fileInfos)
  
    // Prepare the transaction to upload the files
    const transactionsData = await staticFrontendPluginClient.value.prepareAddFilesTransactions(props.websiteVersionIndex, fileInfos);
    console.log(transactionsData);

    return transactionsData;
  },
  onSuccess: (data) => {
    filesAdditionTransactions.value = data.transactions
    skippedFilesAdditions.value = data.skippedFiles
    // Execute right away, don't wait for user confirmation
    executePreparedAddFilesTransactions()
  }
})
const prepareAddFilesTransactions = async () => {
  prepareAddFilesMutate()
}

// Execute an upload transaction
const addFileTransactionBeingExecutedIndex = ref(-1)
const addFileTransactionResults = ref([])
const { isPending: addFilesIsPending, isError: addFilesIsError, error: addFilesError, isSuccess: addFilesIsSuccess, mutate: addFilesMutate, reset: addFilesReset } = useMutation({
  mutationFn: async ({index, transaction}) => {
    // Store infos about the state of the transaction
    addFileTransactionResults.value.push({status: 'pending'})
    addFileTransactionBeingExecutedIndex.value = index

    const hash = await staticFrontendPluginClient.value.executeTransaction(transaction);
    console.log(hash);

    // Wait for the transaction to be mined
    return await staticFrontendPluginClient.value.waitForTransactionReceipt(hash);
  },
  scope: {
    // This scope will make the mutations run serially
    id: 'addFiles'
  },
  onSuccess: async (data) => {
    // Mark the transaction as successful
    addFileTransactionResults.value[addFileTransactionBeingExecutedIndex.value] = {status: 'success'}

    // Refresh the static frontend
    await queryClient.invalidateQueries({ queryKey: ['StaticFrontendPluginStaticFrontend', props.contractAddress, props.chainId, props.websiteVersionIndex] })

    // Refresh the content of the file
    await invalidateStaticFrontendFileContentQuery(queryClient, props.contractAddress, props.chainId, props.websiteVersionIndex, props.fileInfos)

    // If this was the last transaction
    if(addFileTransactionBeingExecutedIndex.value == filesAdditionTransactions.value.length - 1) {

    }
  },
  onError: (error) => {
    // Mark the transaction as failed
    addFileTransactionResults.value[addFileTransactionBeingExecutedIndex.value] = {status: 'error', error}
  }
})
const executePreparedAddFilesTransactions = async () => {
  for(const [index, transaction] of filesAdditionTransactions.value.entries()) {
    addFilesMutate({index, transaction})
  }
}

</script>

<template>
  <div>
    <div>
      <label>Your name</label>
      <input v-model="name" />
    </div>

    <div v-if="prepareAddFilesIsError" class="mutation-error">
      <span>
        Error preparing the transaction to save the config: {{ prepareAddFilesError.shortMessage || prepareAddFilesError.message }} <a @click.stop.prevent="prepareAddFilesReset()">Hide</a>
      </span>
    </div>

    <div v-if="addFilesIsError" class="mutation-error">
      <span>
        Error saving the config: {{ addFilesError.shortMessage || addFilesError.message }} <a @click.stop.prevent="addFilesReset()">Hide</a>
      </span>
    </div>

    <button @click="prepareAddFilesTransactions" :disabled="prepareAddFilesIsPending">Save</button>

  </div>
</template>

<style scoped>
.read-the-docs {
  color: #888;
}
</style>
