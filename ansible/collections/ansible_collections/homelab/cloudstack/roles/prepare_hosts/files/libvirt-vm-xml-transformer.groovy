#!/usr/bin/env groovy
import groovy.util.Node
import groovy.xml.XmlUtil

class GpuPassthroughTransformer {
    String transform(Object logger, String xml) {
        def vmDef = new XmlParser().parseText(xml)

        logger.info("GPU Transformer: Checking VM metadata for GPU passthrough...")

        // Find metadata section
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

        // Fetch available GPUs from the host
        def availableGpus = getAvailableGpus(logger, gpuModel)
        if (availableGpus.size() < gpuCount) {
            logger.error("GPU Transformer: Not enough GPUs available! Requested: ${gpuCount}, Available: ${availableGpus.size()}")
            // Return a specific error message to signal failure
            return "ERROR: Not enough GPUs available! Requested: ${gpuCount}, Available: ${availableGpus.size()}"
        }

    /*
        // Modify the XML by appending GPU devices
        def devicesNode = vmDef.'devices'[0]
        for (int i = 0; i < gpuCount; i++) {
            def gpuPci = availableGpus[i]  // Assign first available GPU
            logger.info("GPU Transformer: Assigning GPU ${gpuPci} to VM.")

            def (bus, slot, function) = gpuPci.tokenize(":.")

            def hostdev = new Node(null, "hostdev", [
                "mode"    : "subsystem",
                "type"    : "pci",
                "managed" : "yes"
            ])
            def driver = new Node(hostdev, "driver", ["name": "vfio"])
            def source = new Node(hostdev, "source")
            new Node(source, "address", [
                "domain"   : "0x0000",
                "bus"      : "0x${bus}",
                "slot"     : "0x${slot}",
                "function" : "0x${function}"
            ])
            new Node(hostdev, "alias", ["name": "nvidia${i}"])

            devicesNode.append(hostdev)  // Append to the devices section
        }
    */

    // Modify the XML by appending GPU devices
    def devicesNode = vmDef.'devices'[0]
    for (int i = 0; i < gpuCount; i++) {
        def gpuPci = availableGpus[i]  // Assign first available GPU
        logger.info("GPU Transformer: Assigning GPU ${gpuPci} to VM.")

        // Adjust PCI address for ARM64 platform
        def (domain, bus, slot, function) = gpuPci.tokenize(":.")

        def hostdev = new Node(null, "hostdev", [
        "mode"    : "subsystem",
        "type"    : "pci",
        "managed" : "yes"
        ])
        def driver = new Node(hostdev, "driver", ["name": "vfio"])
        def source = new Node(hostdev, "source")
        new Node(source, "address", [
        "domain"   : "0x${domain}",  // Use dynamic domain
        "bus"      : "0x${bus}",
        "slot"     : "0x${slot}",
        "function" : "0x${function}"
        ])
        new Node(hostdev, "alias", ["name": "nvidia${i}"])

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
            /*
            // Check if the GPU model matches the requested model
            if (model?.contains(requestedGpuModel)) {
                return true
            }
            */
            return true

            logger.info("GPU Transformer: Skipping ${pciAddress} (model '${model}' does not match requested '${requestedGpuModel}')")
            return false
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
                String domain = null, bus = null, slot = null, function = null

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

            /*
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
                    */

// Check for <address> inside <source>
if (insideHostdev && insideSource && line.contains("<address")) {
    logger.info("GPU Transformer: Checking line -> ${line}")

    // Updated regex to include 'domain' and match correctly
    def match = line =~ /domain='0x([0-9A-Fa-f]+)' bus='0x([0-9A-Fa-f]+)' slot='0x([0-9A-Fa-f]+)' function='0x([0-9A-Fa-f]+)'/

    if (match) {
        domain = match.group(1).toLowerCase().padLeft(4, '0') // Ensure 4-digit format
        bus = match.group(2).toLowerCase().padLeft(2, '0')
        slot = match.group(3).toLowerCase().padLeft(2, '0')
        function = match.group(4).toLowerCase()

        // Construct PCI address including domain
        def gpuAddr = "${domain}:${bus}:${slot}.${function}"
        assignedGpus.add(gpuAddr)

        logger.info("GPU Transformer: Found assigned GPU: ${gpuAddr}")
    } else {
        logger.warn("GPU Transformer: No match found in line: ${line}")
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
}

new GpuPassthroughTransformer()
