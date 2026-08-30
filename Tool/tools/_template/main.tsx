import { EmptyToolState, ToolPage } from "@/ui/index.js";
import { mountTool } from "@/runtime/mount-tool.js";

function Tool() {
  return (
    <ToolPage title="MachKit Tool">
      <EmptyToolState>Replace this template with the tool UI.</EmptyToolState>
    </ToolPage>
  );
}

mountTool(<Tool />, { name: "MachKit Tool" });
