use zed_extension_api as zed;

const MCP_PACKAGE: &str = "mcp-server-pdf-viewer";
const MCP_VERSION: &str = "0.1.0";
const GITHUB_NPX_SOURCE: &str = "github:noelpinto/mcp-server-pdf-viewer";

struct PdfViewerExtension;

impl zed::Extension for PdfViewerExtension {
    fn new() -> Self {
        Self
    }

    fn context_server_command(
        &mut self,
        context_server_id: &zed::ContextServerId,
        _project: &zed::Project,
    ) -> Result<zed::Command, String> {
        if context_server_id.as_ref() != "pdf-viewer" {
            return Err(format!("Unknown context server: {context_server_id}"));
        }

        let node = zed::node_binary_path()?;
        let npx = node.replace("node", "npx");

        let package_arg = if zed::npm_package_installed_version(MCP_PACKAGE)?
            .as_deref()
            == Some(MCP_VERSION)
        {
            format!("{MCP_PACKAGE}@{MCP_VERSION}")
        } else if let Ok(()) = zed::npm_install_package(MCP_PACKAGE, MCP_VERSION) {
            format!("{MCP_PACKAGE}@{MCP_VERSION}")
        } else {
            GITHUB_NPX_SOURCE.to_string()
        };

        Ok(zed::Command {
            command: npx,
            args: vec!["-y".to_string(), package_arg],
            env: vec![],
        })
    }
}

zed::register_extension!(PdfViewerExtension);
