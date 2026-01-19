#!/usr/bin/env groovy
import groovy.util.Node
import groovy.xml.XmlUtil

class GpuPassthroughTransformer {
    String transform(Object logger, String xml) {
        def vmDef = new XmlParser().parseText(xml)

        logger.info("GPU Transformer: Checking VM metadata for GPU passthrough...")

        // Add Windows detection
        def isWindows = false
        def descriptionNode = vmDef.'description'
        if (descriptionNode && descriptionNode.text().toLowerCase().contains("windows")) {
            isWindows = true
            logger.info("GPU Transformer: Windows OS detected")
        }

        // If Windows, add Windows-specific configurations
        if (isWindows) {
            // Add features section with enhanced Hyper-V support
            def featuresNode = vmDef.'features'[0] ?: new Node(vmDef, "features")
            featuresNode.children().clear()  // Clear existing children if any

            new Node(featuresNode, "acpi")
            new Node(featuresNode, "apic")
            def hyperv = new Node(featuresNode, "hyperv")  // Remove mode attribute

            // Standard Hyper-V features
            new Node(hyperv, "relaxed", [state: 'on'])
            new Node(hyperv, "vapic", [state: 'on'])
            new Node(hyperv, "spinlocks", [state: 'on', retries: '8191'])
            new Node(hyperv, "vpindex", [state: 'on'])
            new Node(hyperv, "synic", [state: 'on'])
            new Node(hyperv, "vendor_id", [state: 'on', value: '123456789ab'])
            new Node(hyperv, "stimer", [state: 'on', direct: 'on'])
            new Node(hyperv, "reset", [state: 'on'])           // Better off for GPU passthrough
            new Node(hyperv, "frequencies", [state: 'on'])
            new Node(hyperv, "reenlightenment", [state: 'on'])
            new Node(hyperv, "tlbflush", [state: 'on'])
            new Node(hyperv, "ipi", [state: 'on'])

            // Add KVM hidden state
            def kvm = new Node(featuresNode, "kvm")
            new Node(kvm, "hidden", [state: 'on'])

            // Enhanced memory backing configuration
            def memoryBacking = vmDef.'memoryBacking'[0] ?: new Node(vmDef, "memoryBacking")
            memoryBacking.children().clear()  // Clear existing children if any

            // Create <hugepages> with nested <page>
            def hugepages = new Node(memoryBacking, "hugepages")
            new Node(hugepages, "page", [size: '1', unit: 'G'])

            // Add remaining child elements
            new Node(memoryBacking, "locked")
            new Node(memoryBacking, "allocation", [mode: 'immediate'])
            new Node(memoryBacking, "source", [type: 'memfd'])
            new Node(memoryBacking, "access", [mode: 'shared'])

            def pm = new Node(vmDef, "pm")
            new Node(pm, "suspend-to-disk", [enabled: 'no'])
            new Node(pm, "suspend-to-mem", [enabled: 'no'])

            // Optimize clock for Windows
            def clockNode = vmDef.'clock'[0] ?: new Node(vmDef, "clock")
            clockNode.attributes().put('offset', 'localtime')

            new Node(clockNode, "timer", [name: 'rtc', present: 'no', tickpolicy: 'catchup'])
            new Node(clockNode, "timer", [name: 'pit', present: 'no', tickpolicy: 'delay'])
            new Node(clockNode, "timer", [name: 'hpet', present: 'no'])
            new Node(clockNode, "timer", [name: 'kvmclock', present: 'no'])
            new Node(clockNode, "timer", [name: 'hypervclock', present: 'yes'])

            // Optimize disk for Windows with backing file
            vmDef.'devices'[0].disk.each { disk ->
                if (disk.@device == 'disk') {
                    // Essential settings
                    disk.driver.@cache = 'none'           // Direct I/O
                    disk.driver.@io = 'threads'          // Modern I/O engine
                    disk.driver.@iothread = '1'           // Dedicated I/O thread

                    // QCOW2 specific optimizations
                    disk.driver.@discard = 'unmap'        // Enable TRIM
                    disk.driver.@detect_zeroes = 'unmap'  // Efficient zero handling
                    disk.driver.@queues = '6'             // Single queue for backed images
                }
            }
        }

        // Find metadata section and GPU info
        def metadataNode = vmDef.'metadata'?.find { it.'cloudstack:custom' }
        if (!metadataNode) {
            logger.info("GPU Transformer: No CloudStack custom metadata found. Skipping GPU passthrough.")
            return xml
        }

        // Extract GPU data from metadata
        def customMetadata = metadataNode.'cloudstack:custom'[0]
        def gpuModel = customMetadata.'GPU'?.text()?.trim()
        def gpuCount = customMetadata.'GPU_NUMBERS'?.text()?.trim()?.toInteger() ?: 0

        logger.info("GPU Transformer: Found GPU model '${gpuModel}' with count ${gpuCount}")

        if (gpuCount <= 0) {
            logger.info("GPU Transformer: No GPUs requested. Skipping modification.")
            return xml
        }

        // Fetch available GPUs and their NUMA info
        def availableGpus = getAvailableGpus(logger, gpuModel)
        if (availableGpus.size() < gpuCount) {
            logger.error("GPU Transformer: Not enough GPUs available! Requested: ${gpuCount}, Available: ${availableGpus.size()}")
            // Return a specific error message to signal failure
            return "ERROR: Not enough GPUs available! Requested: ${gpuCount}, Available: ${availableGpus.size()}"
        }

        // Get the first GPU's NUMA node and available CPUs
        def gpuPci = availableGpus[0]
        def numaInfo = getGpuNumaInfo(logger, gpuPci)
        def numaCpus = getNumaNodeCpus(logger, numaInfo.numaNode)

        // Configure CPU topology for single socket
        def vcpuNode = vmDef.'vcpu'[0]
        def cpuNode = vmDef.'cpu'[0] ?: new Node(vmDef, "cpu")

        // Set CPU topology to single socket with explicit core/thread count
        def topology = cpuNode.'topology'[0] ?: new Node(cpuNode, "topology")
        def totalVcpus = vcpuNode.text().toInteger()
        topology.@sockets = "1"
        topology.@cores = "${totalVcpus}"     // All vCPUs as physical cores
        topology.@threads = "1"               // No hyperthreading

        // Remove any existing CPU features to avoid conflicts
        cpuNode.children().findAll { it.name() == 'feature' }.each { it.parent().remove(it) }

        // Add basic topology features that work on both Intel and AMD
        new Node(cpuNode, "feature", [policy: "require", name: "x2apic"])
        new Node(cpuNode, "feature", [policy: "require", name: "apic"])

        // Marcelo: PIN VCPUS in the same NUMA node
        // Add CPU tuning for NUMA optimization
        def cputune = vmDef.'cputune'[0] ?: new Node(vmDef, "cputune")
        cputune.children().clear()  // Clear existing children if any

        // Pin vCPUs to available physical CPUs
        def vcpus = vmDef.'vcpu'?.text()?.toInteger() ?: 1
        assignCpus(logger, cputune, numaCpus, vcpus)

        // Add NUMA memory configuration
        def numatune = vmDef.'numatune'[0] ?: new Node(vmDef, "numatune")
        numatune.children().clear()
        // preferred: try to allocate memory on the specified NUMA node, but allow migration to other nodes if necessary
        // strict: allocate memory on the specified NUMA node only
        new Node(numatune, "memory", [mode: "strict", nodeset: numaInfo.numaNode.toString()])

        // Modify the XML by appending GPU devices
        def devicesNode = vmDef.'devices'[0]
        for (int i = 0; i < gpuCount; i++) {
            def currentGpuPci = availableGpus[i]  // Changed variable name here
            logger.info("GPU Transformer: Assigning GPU ${currentGpuPci} to VM.")

            def (bus, slot, function) = currentGpuPci.tokenize(":.")

            // Remove existing video devices
            vmDef.devices.video.each { videoNode ->
                videoNode.parent().remove(videoNode)
            }

            // Add basic video device for initial boot
            def video = new Node(vmDef.'devices'[0], "video")
            def videoModel = new Node(video, "model", [
                type: 'vga',     // Use VGA instead of cirrus
                vram: '16384',   // Keep some basic VRAM
                heads: '1',
                primary: 'no'    // Allow NVIDIA to be primary
            ])

            // Modify the GPU hostdev configuration
            def hostdev = new Node(null, "hostdev", [
                "mode"    : "subsystem",
                "type"    : "pci",
                "managed" : "yes"
            ])

            // Then add driver configuration
            def driver = new Node(hostdev, "driver", [
                "name": "vfio",
            ])

            def source = new Node(hostdev, "source")
            new Node(source, "address", [
                "domain"   : "0x0000",
                "bus"      : "0x${bus}",
                "slot"     : "0x${slot}",
                "function" : "0x${function}"
            ])

            // ROM and memory settings
            new Node(hostdev, "rom", [
                "bar": "on",
                "enabled": "yes"
            ])

            // Add proper PCI address with multifunction enabled
            new Node(hostdev, "address", [
                "type": "pci",
                "domain": "0x0000",
                "bus": "0x06",
                "slot": "0x00",
                "function": "0x0",
                "multifunction": "on"
            ])

            devicesNode.append(hostdev)  // Append to the devices section
        }

        logger.info("GPU Transformer: Successfully added ${gpuCount} GPUs to the VM XML.")

        return XmlUtil.serialize(vmDef)
    }

    /**
     * Detect available GPUs on the host.
     * This function runs 'lspci' and removes GPUs assigned to running VMs.
     */
    List<String> getAvailableGpus(Object logger, String requestedGpuModel) {
        def assignedGpus = getAssignedGpus(logger)

        // Run `lspci` and capture only NVIDIA VGA controllers (ignore audio devices)
        def lspciOutput = "/usr/bin/lspci -v".execute().text

        // Extract only VGA compatible NVIDIA GPUs (ignoring audio devices)
        def allGpus = lspciOutput.readLines().findAll {
            it.contains("NVIDIA") && it.contains("controller") && it.contains("(rev a1)")
        }.collect { line ->
            def pciAddress = line.split(" ")[0].toLowerCase() // Extract PCI address
            // Keep the full device description after the PCI address
            def model = line.substring(line.indexOf(":") + 1).trim()
            [pciAddress, model]
        }

        logger.info("GPU Transformer: Detected GPUs: ${allGpus}")
        logger.info("GPU Transformer: Assigned GPUs: ${assignedGpus}")

        // Filter GPUs by requested model and remove assigned GPUs
        def filteredGpus = allGpus.findAll { gpu ->
            def (pciAddress, model) = gpu
            def busSlot = pciAddress.replace(".0", "") // Strip function to check both .0 and .1
            if (assignedGpus.contains("${busSlot}.0") || assignedGpus.contains("${busSlot}.1")) {
                logger.info("GPU Transformer: Skipping ${pciAddress} (or its audio device is in use)")
                return false
            }
            // Check if the GPU model matches the requested model
            //if (model?.contains(requestedGpuModel)) {
            return true
            //}
            //logger.info("GPU Transformer: Skipping ${pciAddress} (model '${model}' does not match requested '${requestedGpuModel}')")
            //return false
        }.collect { it[0] } // Extract PCI addresses

        logger.info("GPU Transformer: Available GPUs: ${filteredGpus}")

        return filteredGpus
    }

    /**
     * Get GPUs assigned to running VMs.
     * This reads from libvirt domain XMLs instead of using 'virsh' (which is blocked).
     */
    Set<String> getAssignedGpus(Object logger) {
        def assignedGpus = [] as Set
        def qemuDir = new File("/var/run/libvirt/qemu")

        // Ensure the qemu directory exists
        if (!qemuDir.exists() || !qemuDir.isDirectory()) {
            logger.error("GPU Transformer: QEMU directory not found: ${qemuDir}")
            return assignedGpus
        }

        // Parse each XML file in the directory
        qemuDir.eachFileMatch(~/.*\.xml/) { xmlFile ->
            try {
                logger.info("GPU Transformer: Processing XML file ${xmlFile.name}")

                // Read the file line by line
                def lines = xmlFile.readLines()

                // Variables to track the state
                boolean insideHostdev = false
                boolean insideSource = false
                String bus = null, slot = null, function = null

                // Iterate over each line to find the relevant <hostdev> and <driver>
                lines.each { line ->
                    // Check for <hostdev> opening tag
                    if (line.contains("<hostdev")) {
                        insideHostdev = true
                        bus = slot = function = null  // Reset variables
                    }

                    // Check for <source> opening tag inside <hostdev>
                    if (insideHostdev && line.contains("<source")) {
                        insideSource = true
                    }

                    // Check for <address> inside <source>
                    if (insideHostdev && insideSource && line.contains("<address")) {
                        // Extract PCI address values correctly
                        def match = line =~ /bus='0x([0-9a-f]+)' slot='0x([0-9a-f]+)' function='0x([0-9a-f]+)'/
                        if (match) {
                            bus = match.group(1)
                            slot = match.group(2)
                            function = match.group(3)
                            // Correctly format the PCI address
                            def gpuAddr = "${bus}:${slot}.${function}"
                            assignedGpus.add(gpuAddr)
                            logger.info("GPU Transformer: Found assigned GPU: ${gpuAddr}")
                        }
                    }

                    // Check for <source> closing tag
                    if (insideSource && line.contains("</source>")) {
                        insideSource = false
                    }

                    // Check for <hostdev> closing tag
                    if (insideHostdev && line.contains("</hostdev>")) {
                        insideHostdev = false
                        insideSource = false
                    }
                }

            } catch (Exception e) {
                logger.error("GPU Transformer: Error processing ${xmlFile}: ${e}")
            }
        }

        logger.info("GPU Transformer: GPUs in use: ${assignedGpus}")
        return assignedGpus
    }

    /**
     * Get NUMA node information for a given GPU PCI address
     */
    private Map getGpuNumaInfo(Object logger, String pciAddress) {
        try {
            // Use cat instead of ls to read the file contents
            def numaNode = "cat /sys/bus/pci/devices/0000:${pciAddress}/numa_node".execute().text.trim()
            logger.info("GPU Transformer: GPU ${pciAddress} is on NUMA node ${numaNode}")

            // Handle the case where NUMA node is -1 (not NUMA aware)
            def nodeNum = numaNode.toInteger()
            if (nodeNum < 0) {
                logger.info("GPU Transformer: GPU ${pciAddress} is not NUMA aware, defaulting to node 0")
                nodeNum = 0
            }

            return [numaNode: nodeNum, pciAddress: pciAddress]
        } catch (Exception e) {
            logger.error("GPU Transformer: Error getting NUMA info for GPU ${pciAddress}: ${e}")
            return [numaNode: 0, pciAddress: pciAddress]  // Default to NUMA node 0
        }
    }

    /**
     * Get list of CPU IDs for a specific NUMA node
     */
    private List<Integer> getNumaNodeCpus(Object logger, int numaNode) {
        try {
            // Read directly from the sysfs NUMA node CPU list
            def cpuListFile = new File("/sys/devices/system/node/node${numaNode}/cpulist")
            if (!cpuListFile.exists()) {
                throw new Exception("CPU list file not found for NUMA node ${numaNode}")
            }

            def cpuList = cpuListFile.text.trim()
            def cpus = []

            // Parse CPU list (handles formats like "0-3,7-11")
            cpuList.split(',').each { range ->
                def parts = range.split('-')
                if (parts.size() == 1) {
                    cpus.add(parts[0].toInteger())
                } else {
                    def start = parts[0].toInteger()
                    def end = parts[1].toInteger()
                    (start..end).each { cpus.add(it) }
                }
            }

            logger.info("GPU Transformer: NUMA node ${numaNode} has CPUs: ${cpus}")
            return cpus
        } catch (Exception e) {
            logger.error("GPU Transformer: Error getting CPU list for NUMA node ${numaNode}: ${e}")
            // Get all available CPUs as fallback
            try {
                def allCpus = new File("/sys/devices/system/cpu").list().findAll { it =~ /cpu[0-9]+/ }
                    .collect { it.substring(3).toInteger() }
                    .sort()
                logger.info("GPU Transformer: Falling back to all available CPUs: ${allCpus}")
                return allCpus
            } catch (Exception e2) {
                logger.error("GPU Transformer: Error getting fallback CPU list: ${e2}")
                return [0, 1]  // Return default CPUs if everything fails
            }
        }
    }

    /**
     * Get CPUs assigned to running VMs.
     * This reads from libvirt domain XMLs similar to getAssignedGpus.
     */
    Set<Integer> getAssignedCpus(Object logger) {
        def assignedCpus = [] as Set
        def qemuDir = new File("/var/run/libvirt/qemu")

        // Ensure the qemu directory exists
        if (!qemuDir.exists() || !qemuDir.isDirectory()) {
            logger.error("GPU Transformer: QEMU directory not found: ${qemuDir}")
            return assignedCpus
        }

        // Parse each XML file in the directory
        qemuDir.eachFileMatch(~/.*\.xml/) { xmlFile ->
            try {
                logger.info("GPU Transformer: Processing XML file ${xmlFile.name} for CPU assignments")

                def lines = xmlFile.readLines()
                boolean insideCputune = false

                lines.each { line ->
                    // Check for <cputune> section
                    if (line.contains("<cputune")) {
                        insideCputune = true
                    }

                    // Extract CPU assignments from vcpupin entries
                    if (insideCputune && line.contains("<vcpupin")) {
                        def match = line =~ /cpuset=['"](\d+)['"]/
                        if (match) {
                            def cpu = match.group(1).toInteger()
                            assignedCpus.add(cpu)
                            logger.info("GPU Transformer: Found assigned CPU: ${cpu}")
                        }
                    }

                    if (line.contains("</cputune>")) {
                        insideCputune = false
                    }
                }

            } catch (Exception e) {
                logger.error("GPU Transformer: Error processing ${xmlFile} for CPU assignments: ${e}")
            }
        }

        logger.info("GPU Transformer: CPUs in use: ${assignedCpus}")
        return assignedCpus
    }

    // Modify the CPU assignment section in transform method:
    def assignCpus(def logger, def cputune, def numaCpus, int vcpus) {
        def assignedCpus = getAssignedCpus(logger)
        def availableCpus = numaCpus.findAll { !assignedCpus.contains(it) }

        logger.info("GPU Transformer: Available CPUs on NUMA node: ${availableCpus}")

        if (availableCpus.isEmpty()) {
            logger.warn("GPU Transformer: No free CPUs available, using all NUMA CPUs: ${numaCpus}")
            availableCpus = numaCpus
        }

        // Pin each vCPU to available physical CPUs
        def cpuIndex = 0
        for (int i = 0; i < vcpus; i++) {
            def physicalCpu = availableCpus[cpuIndex % availableCpus.size()]
            new Node(cputune, "vcpupin", [vcpu: i.toString(), cpuset: physicalCpu.toString()])
            logger.info("GPU Transformer: Pinned vCPU ${i} to physical CPU ${physicalCpu}")
            cpuIndex++
        }
    }
}

new GpuPassthroughTransformer()
