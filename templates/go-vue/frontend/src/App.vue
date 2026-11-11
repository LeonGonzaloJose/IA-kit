<script setup lang="ts">
import { onMounted, ref } from 'vue'

const status = ref('checking…')

onMounted(async () => {
  try {
    const res = await fetch('/healthz')
    status.value = res.ok ? (await res.json()).status : `error ${res.status}`
  } catch {
    status.value = 'API unreachable'
  }
})
</script>

<template>
  <main>
    <h1>__TITLE__</h1>
    <p>API: {{ status }}</p>
  </main>
</template>
