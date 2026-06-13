local NetworkUtils = {};

function NetworkUtils.retryingPcall<T...>(callback: (T...) -> any, retries: number?, cooldownScale: number?, ...: T...): (boolean, any)
    if not cooldownScale then cooldownScale = 1.25 end;
    if not retries then retries = 3 end;

    local scale = 0.5;
    local attempt: number = 0;

    while attempt < retries do
        attempt += 1;
        scale *= cooldownScale;

        local success, result = pcall(callback, ...)

        if success and result then
            return true, result
        else
            warn("Call failed: " .. result)
        end

        if attempt < retries then
            task.wait(0.5 * scale);
        end
    end

    return false, nil
end

-- Give it so many retries it effectively runs until we get results, dangerous
function NetworkUtils.brutePcall<T...>(callback: (T...) -> any): (boolean, any)
    return NetworkUtils.retryingPcall(callback, 999, 1);
end

return NetworkUtils;