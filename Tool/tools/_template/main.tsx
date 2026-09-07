import { EmptyToolState, ToolContent, ToolPage } from "@/ui/index.js";
import { mountTool } from "@/runtime/mount-tool.js";

function Tool() {
  return (
    <ToolPage title="MachKit Tool">
      <ToolContent>
        <EmptyToolState>Replace this template with the tool UI.</EmptyToolState>
      </ToolContent>
    </ToolPage>
  );
}

mountTool(<Tool />, { name: "MachKit Tool" });
